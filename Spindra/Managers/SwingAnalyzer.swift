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
    
    // Motion history for smoothing
    private var shoulderRotationHistory: [Double] = []
    private var hipRotationHistory: [Double] = []
    private var wristHeightHistory: [Double] = []
    private let historySize = 5
    
    // Tracking variables
    private var previousShoulderAngle: Double = 0
    private var previousHipAngle: Double = 0
    private var phaseStartTime: Date = Date()
    private var swingStartTime: Date?
    private var peakAngularVelocity: Double = 0
    private var maxShoulderRotation: Double = 0
    private var hipShoulderSeparation: Double = 0
    
    // Biomechanics tracking
    private var backswingDepth: Double = 0
    private var forwardAcceleration: Double = 0
    private var followThroughComplete: Bool = false
    
    // Confidence threshold
    private let minConfidence: Float = 0.4
    
    func analyzeSwing(_ joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        // Validate required joints with higher confidence
        guard let rightShoulder = joints[.rightShoulder],
              let leftShoulder = joints[.leftShoulder],
              let rightElbow = joints[.rightElbow],
              let rightWrist = joints[.rightWrist],
              let rightHip = joints[.rightHip],
              let leftHip = joints[.leftHip],
              rightShoulder.confidence > minConfidence,
              leftShoulder.confidence > minConfidence,
              rightElbow.confidence > minConfidence,
              rightWrist.confidence > minConfidence else {
            feedback = "Position your full body clearly in frame"
            return
        }
        
        // Calculate smoothed metrics
        let shoulderRotation = smoothValue(
            calculateShoulderRotation(leftShoulder: leftShoulder.location, rightShoulder: rightShoulder.location),
            history: &shoulderRotationHistory
        )
        
        let hipRotation = smoothValue(
            calculateHipRotation(leftHip: leftHip.location, rightHip: rightHip.location),
            history: &hipRotationHistory
        )
        
        let wristHeight = smoothValue(
            rightWrist.location.y,
            history: &wristHeightHistory
        )
        
        // Calculate advanced metrics
        let elbowAngle = calculateAngle(
            point1: rightShoulder.location,
            vertex: rightElbow.location,
            point2: rightWrist.location
        )
        
        hipShoulderSeparation = abs(shoulderRotation - hipRotation)
        
        let angularVelocity = abs(shoulderRotation - previousShoulderAngle) / 0.033
        let hipVelocity = abs(hipRotation - previousHipAngle) / 0.033
        
        previousShoulderAngle = shoulderRotation
        previousHipAngle = hipRotation
        
        if angularVelocity > peakAngularVelocity {
            peakAngularVelocity = angularVelocity
        }
        
        // Track kinetic chain (hips lead shoulders)
        let kineticChainSync = hipVelocity > angularVelocity && currentPhase == .forward
        
        processSwingPhase(
            shoulderRotation: shoulderRotation,
            hipRotation: hipRotation,
            elbowAngle: elbowAngle,
            angularVelocity: angularVelocity,
            hipVelocity: hipVelocity,
            wristHeight: wristHeight,
            wristPosition: rightWrist.location,
            hipPosition: leftHip.location,
            kineticChainSync: kineticChainSync
        )
    }
    
    private func smoothValue(_ newValue: Double, history: inout [Double]) -> Double {
        history.append(newValue)
        if history.count > historySize {
            history.removeFirst()
        }
        return history.reduce(0.0, +) / Double(history.count)
    }
    
    private func processSwingPhase(
        shoulderRotation: Double,
        hipRotation: Double,
        elbowAngle: Double,
        angularVelocity: Double,
        hipVelocity: Double,
        wristHeight: Double,
        wristPosition: CGPoint,
        hipPosition: CGPoint,
        kineticChainSync: Bool
    ) {
        switch currentPhase {
        case .ready:
            if abs(shoulderRotation) < 25 && abs(hipRotation) < 20 {
                currentPhase = .preparation
                feedback = "Good stance! Coil into backswing"
                phaseStartTime = Date()
            } else {
                feedback = "Face sideways - shoulders at 90° to camera"
            }
            
        case .preparation:
            if shoulderRotation < -35 && hipRotation < -20 {
                currentPhase = .backswing
                swingStartTime = Date()
                backswingDepth = shoulderRotation
                feedback = "Loading... rotate fully"
            } else if Date().timeIntervalSince(phaseStartTime) > 3.0 {
                feedback = "Start your backswing - turn shoulders away"
            }
            
        case .backswing:
            // Track maximum rotation
            if shoulderRotation < maxShoulderRotation {
                maxShoulderRotation = shoulderRotation
            }
            
            // Good backswing depth check
            if shoulderRotation < -65 {
                feedback = "Perfect coil! Hip-shoulder separation: \(Int(hipShoulderSeparation))°"
            } else if shoulderRotation < -50 {
                feedback = "Good rotation - now accelerate forward"
            }
            
            // Transition to forward swing: shoulders reversing direction with velocity
            if angularVelocity > 15 && shoulderRotation > maxShoulderRotation + 5 {
                currentPhase = .forward
                feedback = "Unwinding! Drive through"
                forwardAcceleration = angularVelocity
            }
            
        case .forward:
            // Check kinetic chain
            if kineticChainSync {
                feedback = "Great kinetic chain! Hips leading"
            } else if hipVelocity < angularVelocity * 0.7 {
                feedback = "Accelerating - use your hips more"
            } else {
                feedback = "Driving forward!"
            }
            
            // Contact zone when shoulders pass neutral
            if shoulderRotation > 15 && angularVelocity > 10 {
                currentPhase = .contact
                feedback = "Contact! Extend through the ball"
            }
            
        case .contact:
            if shoulderRotation > 40 && wristHeight > hipPosition.y + 0.1 {
                currentPhase = .followThrough
                feedback = "Follow through! Finish high"
            } else if Date().timeIntervalSince(phaseStartTime) < 0.3 {
                feedback = "Extend! Stay on target"
            }
            
        case .followThrough:
            // Complete follow-through: wrist finishes high and across body
            let finishHigh = wristHeight > hipPosition.y + 0.15
            let acrossBody = wristPosition.x < hipPosition.x - 0.05
            
            if finishHigh && acrossBody {
                followThroughComplete = true
                feedback = "Complete follow-through!"
            } else if !finishHigh {
                feedback = "Finish higher with your hand"
            } else if !acrossBody {
                feedback = "Follow through across your body"
            }
            
            // Transition to complete
            if angularVelocity < 5 || Date().timeIntervalSince(phaseStartTime) > 1.0 {
                currentPhase = .complete
                completeSwing()
            }
            
        case .complete:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.reset()
            }
        }
        
        phaseStartTime = Date()
    }
    
    private func completeSwing() {
        swingCount += 1
        
        if let startTime = swingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            estimatedSpeed = calculateSpeed()
            formScore = calculateFormScore(duration: duration)
        }
        
        feedback = buildCompletionFeedback()
        
        // Reset swing metrics
        peakAngularVelocity = 0
        maxShoulderRotation = 0
        swingStartTime = nil
        followThroughComplete = false
    }
    
    private func calculateSpeed() -> Double {
        // More accurate speed: angular velocity * arm length estimate * conversion
        let armLengthFactor = 0.75 // meters (estimated racquet + arm)
        let radiansPerSecond = peakAngularVelocity * .pi / 180
        let metersPerSecond = radiansPerSecond * armLengthFactor
        let mph = metersPerSecond * 2.237
        return mph
    }
    
    private func calculateFormScore(duration: TimeInterval) -> Int {
        var score = 50
        
        // Timing (0.7-1.3s optimal)
        if duration > 0.7 && duration < 1.3 {
            score += 15
        } else if duration > 0.6 && duration < 1.5 {
            score += 8
        }
        
        // Backswing depth
        if abs(maxShoulderRotation) > 65 {
            score += 12
        } else if abs(maxShoulderRotation) > 50 {
            score += 6
        }
        
        // Hip-shoulder separation (X-factor)
        if hipShoulderSeparation > 35 {
            score += 12
        } else if hipShoulderSeparation > 25 {
            score += 6
        }
        
        // Speed generation
        if estimatedSpeed > 50 {
            score += 10
        } else if estimatedSpeed > 35 {
            score += 5
        }
        
        // Follow-through completion
        if followThroughComplete {
            score += 11
        }
        
        return min(100, max(0, score))
    }
    
    private func buildCompletionFeedback() -> String {
        let components = [
            "Swing #\(swingCount)",
            formScore >= 80 ? "Excellent!" : formScore >= 65 ? "Good form" : "Form: \(formScore)",
            "\(Int(estimatedSpeed)) mph",
            hipShoulderSeparation > 30 ? "Great separation" : nil
        ].compactMap { $0 }
        
        return components.joined(separator: " • ")
    }
    
    func reset() {
        currentPhase = .ready
        feedback = "Ready for next swing"
        previousShoulderAngle = 0
        previousHipAngle = 0
        shoulderRotationHistory.removeAll()
        hipRotationHistory.removeAll()
        wristHeightHistory.removeAll()
        maxShoulderRotation = 0
        hipShoulderSeparation = 0
    }
    
    // MARK: - Geometry Helpers
    
    private func calculateShoulderRotation(leftShoulder: CGPoint, rightShoulder: CGPoint) -> Double {
        let dx = rightShoulder.x - leftShoulder.x
        let dy = rightShoulder.y - leftShoulder.y
        let angle = atan2(dy, dx) * 180 / .pi
        return angle
    }
    
    private func calculateHipRotation(leftHip: CGPoint, rightHip: CGPoint) -> Double {
        let dx = rightHip.x - leftHip.x
        let dy = rightHip.y - leftHip.y
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
