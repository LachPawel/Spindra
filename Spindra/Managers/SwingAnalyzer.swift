
import Foundation
import Vision
import CoreGraphics

class SwingAnalyzer: ObservableObject {
    @Published var currentPhase: Phase = .ready
    @Published var swingCount: Int = 0
    @Published var formScore: Int = 0
    @Published var estimatedSpeed: Double = 0
    @Published var feedback: String = "Stand sideways to camera"
    @Published var detectedSwingType: SwingType = .unknown
    
    // IMPROVEMENT: Public properties for the coach to analyze trends
    @Published var maxShoulderRotation: Double = 0
    @Published var hipShoulderSeparation: Double = 0
    @Published var followThroughComplete: Bool = false

    enum SwingType {
        case unknown
        case forehand  // Right-handed: body turns right, left shoulder forward
        case backhand  // Right-handed: body turns left, right shoulder forward
    }
    
    // IMPROVEMENT: Added a 'loop' phase for more accurate swing modeling.
    enum Phase {
        case ready
        case preparation
        case backswing
        case loop        // Racquet drops before forward motion
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
    
    // Body orientation tracking
    private var facingDirection: FacingDirection = .unknown
    // IMPROVEMENT: Using a dynamic baseline for more robust stance detection.
    private var shoulderWidthBaseline: CGFloat = 0
    
    enum FacingDirection {
        case unknown
        case leftProfile   // Left shoulder closer to camera
        case rightProfile  // Right shoulder closer to camera
    }
    
    // Confidence threshold
    private let minConfidence: Float = 0.4
    
    func analyzeSwing(_ joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        // Validate required joints
        guard let rightShoulder = joints[.rightShoulder],
              let leftShoulder = joints[.leftShoulder],
              let rightElbow = joints[.rightElbow],
              let rightWrist = joints[.rightWrist],
              let rightHip = joints[.rightHip],
              let leftHip = joints[.leftHip],
              let leftWrist = joints[.leftWrist],
              rightShoulder.confidence > minConfidence,
              leftShoulder.confidence > minConfidence,
              rightHip.confidence > minConfidence,
              leftHip.confidence > minConfidence,
              rightWrist.confidence > minConfidence,
              rightElbow.confidence > minConfidence else {
            feedback = "Position your full body clearly in frame"
            return
        }
        
        detectFacingDirection(leftShoulder: leftShoulder.location, rightShoulder: rightShoulder.location)
        
        if currentPhase == .ready || currentPhase == .preparation {
            detectSwingType(
                leftShoulder: leftShoulder.location,
                rightShoulder: rightShoulder.location,
                leftWrist: leftWrist.location,
                rightWrist: rightWrist.location
            )
        }
        
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
        
        hipShoulderSeparation = abs(shoulderRotation - hipRotation)
        
        let angularVelocity = abs(shoulderRotation - previousShoulderAngle) / 0.033 // Assuming ~30fps
        let hipVelocity = abs(hipRotation - previousHipAngle) / 0.033
        
        previousShoulderAngle = shoulderRotation
        previousHipAngle = hipRotation
        
        if angularVelocity > peakAngularVelocity {
            peakAngularVelocity = angularVelocity
        }
        
        let kineticChainSync = hipVelocity > angularVelocity && currentPhase == .forward
        
        processSwingPhase(
            shoulderRotation: shoulderRotation,
            hipRotation: hipRotation,
            angularVelocity: angularVelocity,
            wristPosition: rightWrist.location,
            elbowPosition: rightElbow.location,
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
        angularVelocity: Double,
        wristPosition: CGPoint,
        elbowPosition: CGPoint,
        hipPosition: CGPoint,
        kineticChainSync: Bool
    ) {
        let rotationMultiplier: Double = (detectedSwingType == .backhand) ? -1.0 : 1.0
        let adjustedRotation = shoulderRotation * rotationMultiplier
        
        switch currentPhase {
        case .ready:
            if abs(shoulderRotation) > 75 && facingDirection != .unknown { // Player is sideways
                currentPhase = .preparation
                let swingName = detectedSwingType == .forehand ? "forehand" : "backhand"
                feedback = "Ready! Begin your \(swingName) backswing."
                phaseStartTime = Date()
            } else if facingDirection == .unknown {
                feedback = "Face sideways - shoulders at 90° to camera"
            }
            
        case .preparation:
            if abs(adjustedRotation) > 35 && abs(hipRotation) > 15 {
                currentPhase = .backswing
                swingStartTime = Date()
                feedback = "Loading... rotate fully"
            }
            
        case .backswing:
            let absRotation = abs(adjustedRotation)
            if absRotation > abs(maxShoulderRotation) {
                maxShoulderRotation = adjustedRotation
            }
            
            // IMPROVEMENT: Transition to LOOP when wrist drops below elbow (racquet drop)
            if wristPosition.y > elbowPosition.y + 0.05 { // Screen Y is inverted
                currentPhase = .loop
                feedback = "Racquet drop, nice and loose"
                phaseStartTime = Date()
            } else if angularVelocity > 15 { // Fallback if loop is missed
                 currentPhase = .forward
            }

        case .loop:
            // IMPROVEMENT: Transition to FORWARD when the shoulder starts unwinding with velocity.
            if angularVelocity > 20 {
                currentPhase = .forward
                feedback = "Unwinding! Drive through"
            }

        case .forward:
            if kineticChainSync {
                feedback = "Great kinetic chain! Hips leading"
            }
            
            // IMPROVEMENT: More precise contact zone check (wrist in front of body)
            let isWristInFront = wristPosition.x < hipPosition.x - 0.1 // For righty, smaller X is in front
            let inContactZone = (detectedSwingType == .forehand && adjustedRotation < -15) ||
                               (detectedSwingType == .backhand && adjustedRotation > 15)
            
            if inContactZone && isWristInFront && angularVelocity > 10 {
                currentPhase = .contact
                feedback = "Contact! Extend through the ball"
            }
            
        case .contact:
            let passedContactZone = (detectedSwingType == .forehand && adjustedRotation < -40) ||
                                    (detectedSwingType == .backhand && adjustedRotation > 40)
            if passedContactZone {
                currentPhase = .followThrough
                feedback = "Follow through! Finish high"
            }
            
        case .followThrough:
            let finishHigh = wristPosition.y < hipPosition.y - 0.15 // Higher on screen = smaller Y
            let acrossBody = abs(wristPosition.x - hipPosition.x) > 0.08
            
            if finishHigh && acrossBody {
                followThroughComplete = true
                feedback = "Complete follow-through!"
            }
            
            if angularVelocity < 10 || Date().timeIntervalSince(phaseStartTime) > 1.0 {
                currentPhase = .complete
                completeSwing()
            }
            
        case .complete:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.reset()
            }
        }
        
        if currentPhase != .complete {
             phaseStartTime = Date()
        }
    }
    
    private func completeSwing() {
        swingCount += 1
        
        if let startTime = swingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            estimatedSpeed = calculateSpeed()
            formScore = calculateFormScore(duration: duration)
        }
        
        feedback = buildCompletionFeedback()
    }
    
    private func calculateSpeed() -> Double {
        let effectiveRadius = 0.6 // meters
        let radiansPerSecond = peakAngularVelocity * .pi / 180.0
        let metersPerSecond = radiansPerSecond * effectiveRadius
        let mph = metersPerSecond * 2.237
        return min(mph, 85.0)
    }
    
    private func calculateFormScore(duration: TimeInterval) -> Int {
        var score = 50
        
        if duration > 0.7 && duration < 1.3 { score += 15 }
        if abs(maxShoulderRotation) > 65 { score += 12 }
        if hipShoulderSeparation > 30 { score += 12 }
        if estimatedSpeed > 45 { score += 10 }
        if followThroughComplete { score += 11 }
        
        return min(100, max(0, score))
    }
    
    private func buildCompletionFeedback() -> String {
        let swingTypeName = detectedSwingType == .forehand ? "Forehand" : "Backhand"
        return "\(swingTypeName) #\(swingCount) • \(formScore) Form • \(Int(estimatedSpeed)) mph"
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
        followThroughComplete = false
        peakAngularVelocity = 0
        swingStartTime = nil
    }
    
    // MARK: - Swing Type & Stance Detection
    
    // IMPROVEMENT: Uses a baseline to more reliably detect a profile/sideways stance.
    private func detectFacingDirection(leftShoulder: CGPoint, rightShoulder: CGPoint) {
        let currentWidth = abs(rightShoulder.x - leftShoulder.x)

        if shoulderWidthBaseline == 0 || currentWidth > shoulderWidthBaseline {
            shoulderWidthBaseline = currentWidth
        }

        if shoulderWidthBaseline > 0 && currentWidth < shoulderWidthBaseline * 0.75 {
            if leftShoulder.x < rightShoulder.x {
                facingDirection = .leftProfile
            } else {
                facingDirection = .rightProfile
            }
        } else {
            facingDirection = .unknown
        }
    }
    
    private func detectSwingType(
        leftShoulder: CGPoint,
        rightShoulder: CGPoint,
        leftWrist: CGPoint,
        rightWrist: CGPoint
    ) {
        guard facingDirection != .unknown else {
            detectedSwingType = .unknown
            return
        }
        
        if facingDirection == .leftProfile {
            detectedSwingType = .forehand // Righty forehand
        } else if facingDirection == .rightProfile {
            detectedSwingType = .backhand // Righty backhand
        } else {
            detectedSwingType = .unknown
        }

        if detectedSwingType != .unknown && (currentPhase == .ready || currentPhase == .preparation) {
            feedback = "Ready for \(detectedSwingType == .forehand ? "forehand" : "backhand")"
        }
    }
    
    // MARK: - Geometry Helpers (unchanged)
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
}
