import Foundation
import AVFoundation
import Combine

enum SoundEffect: String {
    case seedMorph = "seed_morph"
    case seedPlant = "seed_plant"
    case growthTick = "growth_tick"
    case bloom = "bloom"
    case success = "success"
    case warning = "warning"
}

class AudioManager: ObservableObject {
    static let shared = AudioManager()

    private var audioPlayers: [SoundEffect: AVAudioPlayer] = [:]
    @Published var soundsEnabled: Bool = true

    private init() {
        preloadSounds()
    }

    private func preloadSounds() {
        // Preload all sound effects
        // Note: Audio files don't exist yet - this will fail silently
        SoundEffect.allCases.forEach { sound in
            if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    audioPlayers[sound] = player
                } catch {
                    print("Failed to preload sound: \(sound.rawValue)")
                }
            }
        }
    }

    func play(_ sound: SoundEffect, volume: Float = 1.0) {
        guard soundsEnabled else { return }

        if let player = audioPlayers[sound] {
            player.volume = volume
            player.play()
        } else {
            print("Sound not found: \(sound.rawValue)")
        }
    }

    func stop(_ sound: SoundEffect) {
        audioPlayers[sound]?.stop()
    }

    func stopAll() {
        audioPlayers.values.forEach { $0.stop() }
    }
}

extension SoundEffect: CaseIterable {}
