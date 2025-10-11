//
//  MotionManager.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


import Foundation
import SwiftUI
import CoreMotion
import Combine

@MainActor
class MotionManager: ObservableObject {
    static let shared = MotionManager()
    
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    @Published var isTracking: Bool = false
    
    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 0.1
    
    init() {
        setupMotionManager()
    }
    
    private func setupMotionManager() {
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = updateInterval
    }
    
    func startTracking() {
        guard !isTracking && motionManager.isDeviceMotionAvailable else { return }
        
        isTracking = true
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            Task { @MainActor in
                self.pitch = motion.attitude.pitch
                self.roll = motion.attitude.roll
            }
        }
        
        print("✅ Motion tracking started")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        isTracking = false
        motionManager.stopDeviceMotionUpdates()
        pitch = 0.0
        roll = 0.0
        
        print("🛑 Motion tracking stopped")
    }
}
