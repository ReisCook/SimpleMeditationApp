//
//  ContentView.swift
//  SimpleMeditation
//
//  Created by Reis Cook on 12/20/23.
//

import SwiftUI
import AVFoundation

// Define the Soundtrack enum at the top level of the file
enum Soundtrack: String, CaseIterable, Identifiable {
    case rain = "Rain"
    case ocean = "Ocean"
    case underwater = "Underwater"
    case stream = "Stream"
    
    var id: String { self.rawValue }
    
    var url: URL {
        guard let path = Bundle.main.path(forResource: self.rawValue, ofType: "mp3") else {
            fatalError("Failed to find path for sound file named \(self.rawValue).mp3")
        }
        return URL(fileURLWithPath: path)
    }
}


import AVFoundation

import AVFoundation

class SoundManager: ObservableObject {
    static let shared = SoundManager() // Singleton instance
    var audioPlayers: [Soundtrack: AVAudioPlayer] = [:]
    var selectedSoundtrack: Soundtrack? = nil

    
    func playSound(sound: Soundtrack?) {
        if let sound = sound, let player = audioPlayers[sound], !player.isPlaying {
            stopSound() // Stop other sounds
            selectedSoundtrack = sound
            player.numberOfLoops = -1
            player.play()
        } else if sound == nil {
            stopSound() // Stop all sounds if 'nil' is passed
        }
    }



    func stopSound() {
        audioPlayers.values.forEach { $0.stop() }
    }

    
    func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session category. \(error)")
        }
    }



    func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAudioSessionInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())
    }

    @objc func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                  return
        }

        if type == .began {
            // Pause all audio players
            for player in audioPlayers.values {
                player.pause()
            }
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Resume playing for the current soundtrack
                    if let selectedSoundtrack = selectedSoundtrack, let player = audioPlayers[selectedSoundtrack] {
                        player.play()
                    }
                }
            }
        }
    }




    init() {
        configureAudioSession()
        setupInterruptionObserver()
        preloadSounds()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    func preloadSounds() {
        Soundtrack.allCases.forEach { soundtrack in
            if let player = createAudioPlayer(for: soundtrack) {
                audioPlayers[soundtrack] = player
            }
        }
    }
    func createAudioPlayer(for soundtrack: Soundtrack) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: soundtrack.rawValue, withExtension: "mp3") else {
            print("Sound file \(soundtrack.rawValue).mp3 not found.")
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }


}




import SwiftUI

struct ContentView: View {
    let phases = ["Breathe", "Hold", "Exhale"]
    @State private var durations = [5.0, 3.0, 5.0]
    @State private var currentPhaseIndex = 0
    @State private var timeRemaining: Double
    @State private var showSettings = false
    @State private var selectedSoundtrack: Soundtrack? = nil
    @State private var isSoundEnabled = false
    @State private var isPlayingSound = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        _timeRemaining = State(initialValue: 5.0)
    }

    var body: some View {
        NavigationView {
            VStack {
                Text(phases[currentPhaseIndex])
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .edgesIgnoringSafeArea(.all)
                    .onReceive(timer) { _ in
                        if timeRemaining <= 0 {
                            currentPhaseIndex = (currentPhaseIndex + 1) % phases.count
                            timeRemaining = durations[currentPhaseIndex]
                            isPlayingSound = false

                            if isSoundEnabled, let soundtrack = selectedSoundtrack {
                                SoundManager.shared.playSound(sound: soundtrack)
                            } else {
                                SoundManager.shared.playSound(sound: nil)
                            }
                        } else {
                            timeRemaining -= 1
                        }
                    }

                Button("Settings") {
                    showSettings.toggle()
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.black)
                .cornerRadius(10)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(durations: $durations,
                             selectedSoundtrack: $selectedSoundtrack,
                             isSoundEnabled: $isSoundEnabled) {
                    showSettings = false // This will dismiss the settings view
                }
            }
        }
        .colorScheme(.dark)
        .onAppear {
            timeRemaining = durations[currentPhaseIndex]
        }
    }
}

struct SettingsView: View {
    @Binding var durations: [Double]
        @Binding var selectedSoundtrack: Soundtrack?
        @Binding var isSoundEnabled: Bool
        var onDone: () -> Void

        private var numberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.allowsFloats = true
            formatter.minimum = 0
            return formatter
        }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Phase Durations")) {
                    ForEach(0..<durations.count, id: \.self) { index in
                        HStack {
                            Text("Phase \(index + 1)")
                            Spacer()
                            TextField("Seconds", value: $durations[index], formatter: numberFormatter)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                Section(header: Text("Soundtrack")) {
                    Toggle("Enable Soundtrack", isOn: $isSoundEnabled)
                    
                    if isSoundEnabled {
                        Picker("Select Soundtrack", selection: $selectedSoundtrack) {
                            Text("None").tag(Soundtrack?.none)
                            ForEach(Soundtrack.allCases) { soundtrack in
                                Text(soundtrack.rawValue).tag(soundtrack as Soundtrack?)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                    }
                }
            }
            .navigationBarTitle("Settings", displayMode: .inline)
                        .navigationBarItems(trailing: Button("Done") {
                            onDone() // Call the closure to dismiss the view
                        })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


