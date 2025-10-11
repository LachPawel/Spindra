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
    private var clickPlayer: AVAudioPlayer?
    private var successPlayer: AVAudioPlayer?
    private var errorPlayer: AVAudioPlayer?
    
    @Published var isVoiceCoachActive: Bool = false
    private let audioQueue = DispatchQueue(label: "com.spindra.audioQueue", qos: .userInteractive)
    private var isAudioSessionConfigured = false
    
    private init() {
        configureAudioSession()
        preloadSounds()
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession(forVoiceCoach: Bool = false) {
        audioQueue.async {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                
                if forVoiceCoach {
                    // Configure for voice communication - this is the key fix!
                    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
                    print("✅ Audio session configured for voice coaching")
                } else {
                    // Configure for ambient sound
                    try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                    print("✅ Audio session configured for ambient background audio")
                }
                
                try audioSession.setActive(true)
                
                DispatchQueue.main.async {
                    self.isAudioSessionConfigured = true
                }
            } catch {
                print("❌ Failed to configure audio session: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Voice Coach Integration
    func prepareForVoiceCoach() {
        print("🎵 Preparing audio for voice coach")
        isVoiceCoachActive = true
        configureAudioSession(forVoiceCoach: true)
    }
    
    func voiceCoachEnded() {
        print("🎵 Voice coach ended - restoring ambient audio")
        isVoiceCoachActive = false
        configureAudioSession(forVoiceCoach: false)
    }
    
    func setVoiceCoachActive(_ active: Bool) {
        if active {
            prepareForVoiceCoach()
        } else {
            voiceCoachEnded()
        }
    }
    
    // MARK: - Sound Preloading
    private func preloadSounds() {
        preloadTapSound()
        preloadSuccessSound()
        preloadErrorSound()
    }
    
    private func preloadTapSound() {
        audioQueue.async {
            // Try NSDataAsset first
            if let dataAsset = NSDataAsset(name: "tap") {
                do {
                    let player = try AVAudioPlayer(data: dataAsset.data)
                    player.prepareToPlay()
                    player.volume = 0.8
                    
                    DispatchQueue.main.async {
                        self.audioPlayer = player
                    }
                } catch {
                    print("❌ Error preloading tap sound from asset: \(error.localizedDescription)")
                }
            }
            // Fallback to bundle resource
            else if let url = Bundle.main.url(forResource: "tap", withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.volume = 0.8
                    
                    DispatchQueue.main.async {
                        self.audioPlayer = player
                    }
                } catch {
                    print("❌ Error preloading tap sound from bundle: \(error.localizedDescription)")
                }
            } else {
                print("❌ Sound file not found: tap")
            }
        }
    }
    
    private func preloadSuccessSound() {
        audioQueue.async {
            // Try NSDataAsset first
            if let dataAsset = NSDataAsset(name: "success") {
                do {
                    let player = try AVAudioPlayer(data: dataAsset.data)
                    player.prepareToPlay()
                    player.volume = 0.8
                    
                    DispatchQueue.main.async {
                        self.successPlayer = player
                    }
                } catch {
                    print("❌ Error preloading success sound from asset: \(error.localizedDescription)")
                }
            }
            // Fallback to bundle resource
            else if let url = Bundle.main.url(forResource: "success", withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.volume = 0.8
                    
                    DispatchQueue.main.async {
                        self.successPlayer = player
                    }
                } catch {
                    print("❌ Error preloading success sound from bundle: \(error.localizedDescription)")
                }
            } else {
                print("❌ Sound file not found: success")
            }
        }
    }
    
    private func preloadErrorSound() {
        audioQueue.async {
            // Try NSDataAsset first
            if let dataAsset = NSDataAsset(name: "error") {
                do {
                    let player = try AVAudioPlayer(data: dataAsset.data)
                    player.prepareToPlay()
                    player.volume = 0.7
                    
                    DispatchQueue.main.async {
                        self.errorPlayer = player
                    }
                } catch {
                    print("❌ Error preloading error sound from asset: \(error.localizedDescription)")
                }
            }
            // Fallback to bundle resource
            else if let url = Bundle.main.url(forResource: "error", withExtension: "mp3") {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.volume = 0.7
                    
                    DispatchQueue.main.async {
                        self.errorPlayer = player
                    }
                } catch {
                    print("❌ Error preloading error sound from bundle: \(error.localizedDescription)")
                }
            } else {
                print("❌ Sound file not found: error")
            }
        }
    }
    
    // MARK: - Sound Playback
    func playSound(named soundName: String, volume: Float = 0.8) {
        // Reduce volume when voice coach is active to avoid interference
        let adjustedVolume = isVoiceCoachActive ? volume * 0.3 : volume
        
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
                    player.volume = adjustedVolume
                    
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
                    player.volume = adjustedVolume
                    
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
        audioQueue.async { [weak self] in
            guard let self = self, let audioPlayer = self.audioPlayer else { return }
            
            let adjustedVolume: Float = self.isVoiceCoachActive ? 0.2 : 0.7
            audioPlayer.volume = adjustedVolume
            audioPlayer.stop()
            audioPlayer.currentTime = 0
            audioPlayer.play()
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    func playSuccessSound() {
        audioQueue.async { [weak self] in
            guard let self = self, let successPlayer = self.successPlayer else { return }
            
            let adjustedVolume: Float = self.isVoiceCoachActive ? 0.2 : 0.8
            successPlayer.volume = adjustedVolume
            successPlayer.stop()
            successPlayer.currentTime = 0
            successPlayer.play()
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    func playErrorSound() {
        audioQueue.async { [weak self] in
            guard let self = self, let errorPlayer = self.errorPlayer else { return }
            
            let adjustedVolume: Float = self.isVoiceCoachActive ? 0.2 : 0.7
            errorPlayer.volume = adjustedVolume
            errorPlayer.stop()
            errorPlayer.currentTime = 0
            errorPlayer.play()
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

// MARK: - Extensions for backward compatibility
extension SoundManager {
    func ensureAudioSessionForVoiceCoach() {
        guard !isAudioSessionConfigured || !isVoiceCoachActive else { return }
        configureAudioSession(forVoiceCoach: true)
    }
    
    func resetAudioSessionAfterVoiceCoach() {
        guard isVoiceCoachActive else { return }
        configureAudioSession(forVoiceCoach: false)
    }
}
