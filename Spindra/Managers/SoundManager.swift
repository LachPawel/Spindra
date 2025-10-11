//
//  SoundManager.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


import Foundation
import UIKit
import AVFoundation

class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private let audioQueue = DispatchQueue(label: "com.spindra.audioQueue", qos: .userInteractive)
    
    private init() {
        configureAudioSession()
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        audioQueue.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try audioSession.setActive(true)
                print("✅ Audio session configured")
            } catch {
                print("❌ Failed to configure audio session: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Sound Playback
    func playSound(named soundName: String, volume: Float = 0.8) {
        // Keep haptics on main thread for immediate response
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Move audio playback to background queue
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Try to load from NSDataAsset first
            if let dataAsset = NSDataAsset(name: soundName) {
                do {
                    let player = try AVAudioPlayer(data: dataAsset.data)
                    player.prepareToPlay()
                    player.volume = volume
                    
                    DispatchQueue.main.async {
                        self.audioPlayer = player
                        player.play()
                    }
                } catch {
                    print("❌ Error playing sound from asset: \(error.localizedDescription)")
                }
            }
            // Fallback to bundle resource
            else if let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.volume = volume
                    
                    DispatchQueue.main.async {
                        self.audioPlayer = player
                        player.play()
                    }
                } catch {
                    print("❌ Error playing sound from bundle: \(error.localizedDescription)")
                }
            } else {
                print("❌ Sound file not found: \(soundName)")
            }
        }
    }
    
    // MARK: - Convenience Methods
    func playTapSound() {
        playSound(named: "tap", volume: 0.7)
    }
    
    func playSuccessSound() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        playSound(named: "success", volume: 0.8)
    }
    
    func playErrorSound() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        playSound(named: "error", volume: 0.7)
    }
}

// Add these methods to SoundManager.swift

extension SoundManager {
    func prepareForVoiceCoach() {
        audioQueue.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker, .allowBluetooth]
                )
                try audioSession.setActive(true)
                print("✅ Audio session configured for voice coach")
            } catch {
                print("❌ Failed to configure voice session: \(error)")
            }
        }
    }
    
    func voiceCoachEnded() {
        audioQueue.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try audioSession.setActive(true)
                print("✅ Audio session reset after voice coach")
            } catch {
                print("❌ Failed to reset audio: \(error)")
            }
        }
    }
}
