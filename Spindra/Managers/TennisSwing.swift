//
//  TennisSwing.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


//
//  TennisSwing.swift
//  Spindra
//

import Foundation
import CoreGraphics

struct TennisSwing: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let swingType: SwingType
    let phases: [SwingPhase]
    let metrics: SwingMetrics
    
    enum SwingType: String, Codable {
        case forehand = "Forehand"
        case backhand = "Backhand"
        case serve = "Serve"
        case volley = "Volley"
    }
    
    struct SwingPhase: Codable {
        let name: String
        let duration: TimeInterval
        let qualityScore: Double
    }
    
    struct SwingMetrics: Codable {
        let totalDuration: TimeInterval
        let peakSpeed: Double
        let shoulderRotation: Double
        let hipRotation: Double
        let formScore: Int
        let consistency: Double
    }
}

struct PlayerProfile: Codable {
    var playerName: String = "Player"
    var totalSwings: Int = 0
    var totalSessions: Int = 0
    var averageFormScore: Double = 0
    var swingHistory: [TennisSwing] = []
    var bestSpeed: Double = 0
    
    mutating func addSwing(_ swing: TennisSwing) {
        swingHistory.append(swing)
        totalSwings += 1
        
        if swing.metrics.peakSpeed > bestSpeed {
            bestSpeed = swing.metrics.peakSpeed
        }
        
        let totalScore = swingHistory.reduce(0.0) { $0 + Double($1.metrics.formScore) }
        averageFormScore = totalScore / Double(swingHistory.count)
    }
}