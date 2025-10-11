//
//  SwingAnalyzer.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


//
//  SwingAnalyzer.swift
//  Spindra
//

import Foundation
import Vision
import CoreGraphics

class SwingAnalyzer: ObservableObject {
    @Published var currentPhase: Phase = .ready
    @Published var swingCount: Int = 0
    @Published var formScore: Int = 0
    @Published var estimatedSpeed: Double = 0
    @Published var feedback: String = "Stand sideways to camera"
    
    enum Phase {
        case ready
        case preparation
        case backswing
        case forward
        case contact
        case followThrough
        case complete
    }
    
    private var previousShoulderAngle: Double = 0
    private var phaseStartTime: Date = Date()
    private var swingStartTime: Date?
    private var peakAngularVelocity: Double = 0
    
    func analyzeSwing(_ joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        guard let rightShoulder = joints[.rightShoulder],
              let leftShoulder = joints[.leftShoulder],
              let rightElbow = joints[.rightElbow],
              let rightWrist = joints[.rightWrist],
              let rightHip = joints[.rightHip],
              let leftHip = joints[.leftHip],
              rightShoulder.confidence > 0.3,
              leftShoulder.confidence > 0.3 else {
            feedback = "Position your full body in frame"
            return
        }
        
        let shoulderRotation = calculateShoulderRotation(
            leftShoulder: leftShoulder.location,
            rightShoulder: rightShoulder.location
        )
        
        let elbowAngle = calculateAngle(
            point1: rightShoulder.location,
            vertex: rightElbow.location,
            point2: rightWrist.location
        )
        
        let angularVelocity = abs(shoulderRotation - previousShoulderAngle) / 0.033
        previousShoulderAngle = shoulderRotation
        
        if angularVelocity > peakAngularVelocity {
            peakAngularVelocity = angularVelocity
        }
        
        processSwingPhase(
            shoulderRotation: shoulderRotation,
            elbowAngle: elbowAngle,
            angularVelocity: angularVelocity,
            wristPosition: rightWrist.location,
            hipPosition: leftHip.location
        )
    }
    
    private func processSwingPhase(
        shoulderRotation: Double,
        elbowAngle: Double,
        angularVelocity: Double,
        wristPosition: CGPoint,
        hipPosition: CGPoint
    ) {
        switch currentPhase {
        case .ready:
            if abs(shoulderRotation) < 20 {
                currentPhase = .preparation
                feedback = "Good stance! Begin your backswing"
                phaseStartTime = Date()
            } else {
                feedback = "Turn sideways to camera"
            }
            
        case .preparation:
            if shoulderRotation < -45 {
                currentPhase = .backswing
                swingStartTime = Date()
                feedback = "Good rotation! Now accelerate forward"
            }
            
        case .backswing:
            if shoulderRotation < -60 {
                feedback = "Maximum coil achieved"
            }
            
            if angularVelocity > 20 && shoulderRotation > -50 {
                currentPhase = .forward
                feedback = "Accelerating!"
            }
            
        case .forward:
            if shoulderRotation > 20 {
                currentPhase = .contact
                feedback = "Contact zone!"
            }
            
        case .contact:
            if shoulderRotation > 45 {
                currentPhase = .followThrough
                feedback = "Follow through!"
            }
            
        case .followThrough:
            if wristPosition.x < hipPosition.x {
                currentPhase = .complete
                completeSwing()
            }
            
        case .complete:
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.reset()
            }
        }
    }
    
    private func completeSwing() {
        swingCount += 1
        
        if let startTime = swingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            estimatedSpeed = peakAngularVelocity * 0.7 * 2.237
            formScore = calculateFormScore(duration: duration)
        }
        
        feedback = "Swing #\(swingCount) complete! Speed: \(Int(estimatedSpeed)) mph"
        
        peakAngularVelocity = 0
        swingStartTime = nil
    }
    
    private func calculateFormScore(duration: TimeInterval) -> Int {
        var score = 70
        
        if duration > 0.8 && duration < 1.2 {
            score += 10
        }
        
        if estimatedSpeed > 40 {
            score += 10
        }
        
        if peakAngularVelocity > 15 && peakAngularVelocity < 35 {
            score += 10
        }
        
        return min(100, score)
    }
    
    func reset() {
        currentPhase = .ready
        feedback = "Ready for next swing"
        previousShoulderAngle = 0
    }
    
    // MARK: - Geometry Helpers
    
    private func calculateShoulderRotation(
        leftShoulder: CGPoint,
        rightShoulder: CGPoint
    ) -> Double {
        let dx = rightShoulder.x - leftShoulder.x
        let dy = rightShoulder.y - leftShoulder.y
        let angle = atan2(dy, dx) * 180 / .pi
        return angle
    }
    
    private func calculateAngle(point1: CGPoint, vertex: CGPoint, point2: CGPoint) -> Double {
        let vector1 = CGPoint(x: point1.x - vertex.x, y: point1.y - vertex.y)
        let vector2 = CGPoint(x: point2.x - vertex.x, y: point2.y - vertex.y)
        
        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitude1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitude2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }
        
        let cosineAngle = dotProduct / (magnitude1 * magnitude2)
        let angleRadians = acos(min(max(cosineAngle, -1), 1))
        return angleRadians * 180 / .pi
    }
}
