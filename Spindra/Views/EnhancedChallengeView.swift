//
//  EnhancedChallengeView.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


import SwiftUI
import AVFoundation
import SceneKit
import Combine
import Vision

struct EnhancedChallengeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var poseEstimator = TennisPoseEstimator()
    @StateObject private var swingAnalyzer = EnhancedSwingAnalyzer()
    @StateObject private var sceneManager = TennisSceneManager()
    @StateObject private var voiceCoach: TennisVoiceCoach
    @Environment(\.dismiss) var dismiss
    
    @State private var showingStylePicker = false
    @State private var selectedStyle: TennisCoachingStyle = .proCoach
    @State private var cancellables = Set<AnyCancellable>()
    
    init() {
        let agentId = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_AGENT_ID") as? String ?? ""
        _voiceCoach = StateObject(wrappedValue: TennisVoiceCoach(agentId: agentId))
    }
    
    var body: some View {
        ZStack {
            // Camera + 3D overlay
            ZStack {
                CameraPreviewView(session: poseEstimator.captureSession)
                SceneKitView(sceneManager: sceneManager)
            }
            .ignoresSafeArea()
            
            // Skeleton overlay
            GeometryReader { geometry in
                if poseEstimator.isDetectingPerson {
                    SwingSkeletonView(
                        joints: poseEstimator.detectedJoints,
                        size: geometry.size,
                        phase: swingAnalyzer.currentPhase
                    )
                }
            }
            
            VStack {
                topBar
                Spacer()
                statsDisplay
                Spacer()
                controlButtons
            }
        }
        .onAppear { setupSession() }
        .onDisappear { cleanupSession() }
        .sheet(isPresented: $showingStylePicker) {
            CoachingStylePicker(selectedStyle: $selectedStyle) {
                Task {
                    await voiceCoach.endSession()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await startVoiceCoach(style: selectedStyle)
                }
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: {
                Task {
                    await voiceCoach.endSession()
                    poseEstimator.stopSession()
                    appState.currentScreen = .home
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(swingAnalyzer.enhancedSwingType.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                if voiceCoach.isEnabled {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Coach Active")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            Button(action: { showingStylePicker = true }) {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 60)
    }
    
    private var statsDisplay: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                VStack {
                    Text("\(swingAnalyzer.swingCount)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "C4D600"))
                    Text("SWINGS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                VStack {
                    Text("\(swingAnalyzer.formScore)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("FORM")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            if swingAnalyzer.estimatedSpeed > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .foregroundColor(Color(hex: "C4D600"))
                    Text("\(Int(swingAnalyzer.estimatedSpeed)) MPH")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
            }
            
            VStack(spacing: 8) {
                Text(swingAnalyzer.feedback)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            Button(action: { sceneManager.spawnBall() }) {
                Image(systemName: "tennis.racket")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color(hex: "C4D600"))
                    .clipShape(Circle())
            }
            
            Button(action: { Task { await voiceCoach.toggleMute() } }) {
                Image(systemName: voiceCoach.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(voiceCoach.isMuted ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 60)
    }
    
    private func setupSession() {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        poseEstimator.swingAnalyzer = swingAnalyzer
        poseEstimator.setupCamera()
        poseEstimator.startSession()
        
        Task {
            await startVoiceCoach(style: selectedStyle)
            
            // Main update loop is now handled by SceneKit's delegate
            // We only need to sink timers for logic updates
            
            // This publisher now only updates racket *target* position and checks for hits
            Timer.publish(every: 0.033, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    // Update racket target position
                    sceneManager.updateRacketPosition(
                        from: poseEstimator.detectedJoints,
                        swingSpeed: swingAnalyzer.currentSwingSpeed
                    )
                    
                    // Check for hits
                    if sceneManager.checkBallHit() {
                        swingAnalyzer.registerHit()
                        SoundManager.shared.playSuccessSound()
                    }
                }
                .store(in: &cancellables)
            
            // Voice coach feedback loop remains the same
            Timer.publish(every: 0.5, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    Task { await voiceCoach.processSwingAnalysis(swingAnalyzer) }
                }
                .store(in: &cancellables)
        }
    }
    
    private func cleanupSession() {
        poseEstimator.stopSession()
        Task { await voiceCoach.endSession() }
        cancellables.removeAll()
    }
    
    private func startVoiceCoach(style: TennisCoachingStyle) async {
        let sessionData = TennisSessionData(
            sessionTitle: "Forehand Practice",
            swingType: .forehand,
            targetSwings: 20,
            playerName: "Player"
        )
        await voiceCoach.startSession(with: sessionData, style: style)
    }
}

// MARK: - SceneKit View
struct SceneKitView: UIViewRepresentable {
    @ObservedObject var sceneManager: TennisSceneManager
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = sceneManager.scene
        sceneView.backgroundColor = .clear
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = false
        // Set the coordinator as the delegate to receive render loop updates
        sceneView.delegate = context.coordinator
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Coordinator bridges UIKit delegates to SwiftUI
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: SceneKitView
        
        init(_ parent: SceneKitView) {
            self.parent = parent
        }
        
        // This function is called on every frame render
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            parent.sceneManager.updateScene(atTime: time)
        }
    }
}

// MARK: - Scene Manager
class TennisSceneManager: ObservableObject {
    let scene = SCNScene()
    private var racketNode: SCNNode?
    private var ballNodes: [SCNNode] = []
    private var cameraNode: SCNNode!
    private var autoSpawnTimer: Timer?
    private var floorNode: SCNNode?
    
    @Published var ballsSpawned = 0
    @Published var ballsHit = 0
    
    // Target position for smooth movement
    private var targetRacketPosition: SCNVector3 = .init(0, 0, -2)
    private var currentSwingSpeed: Float = 0
    
    init() {
        setupScene()
        createRacket()
        createFloor()
        startAutoSpawn()
    }
    
    private func setupScene() {
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 400
        scene.rootNode.addChildNode(ambientLight)
    }
    
    private func createFloor() {
        let floorGeometry = SCNBox(width: 10, height: 0.1, length: 10, chamferRadius: 0)
        floorGeometry.firstMaterial?.diffuse.contents = UIColor.clear
        floorNode = SCNNode(geometry: floorGeometry)
        floorNode?.position = SCNVector3(0, -3, -5) // Move floor back to catch balls
        floorNode?.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floorNode?.physicsBody?.categoryBitMask = 2
        floorNode?.physicsBody?.collisionBitMask = 1
        scene.rootNode.addChildNode(floorNode!)
    }
    
    private func createRacket() {
        guard let racketURL = Bundle.main.url(forResource: "tennis_racket", withExtension: "usdz"),
              let racketScene = try? SCNScene(url: racketURL, options: nil) else {
            print("❌ Failed to load tennis racket USDZ")
            createFallbackRacket()
            return
        }
        
        racketNode = racketScene.rootNode.clone()
        racketNode?.scale = SCNVector3(0.015, 0.015, 0.015)
        
        racketNode?.eulerAngles.x = .pi / 2
//        racketNode?.eulerAngles = SCNVector3(120, 40, Float(30) + 3 * .pi / 2)
        
        let collisionBox = SCNBox(width: 0.35, height: 0.4, length: 0.15, chamferRadius: 0)
        racketNode?.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: collisionBox, options: nil))
        racketNode?.physicsBody?.categoryBitMask = 4
        racketNode?.physicsBody?.collisionBitMask = 1
        racketNode?.physicsBody?.contactTestBitMask = 1
        
        racketNode?.position = SCNVector3(0, 0, -2)
        scene.rootNode.addChildNode(racketNode!)
    }
    
    private func createFallbackRacket() {
        let racketContainer = SCNNode()
        let headWidth: CGFloat = 0.25
        let headHeight: CGFloat = 0.32
        let headPath = UIBezierPath(ovalIn: CGRect(x: -headWidth/2, y: -headHeight/2, width: headWidth, height: headHeight))
        let headShape = SCNShape(path: headPath, extrusionDepth: 0.02)
        headShape.firstMaterial?.diffuse.contents = UIColor.systemBlue
        let headNode = SCNNode(geometry: headShape)
        
        let handleGeometry = SCNCylinder(radius: 0.018, height: 0.3)
        handleGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
        let handleNode = SCNNode(geometry: handleGeometry)
        handleNode.position = SCNVector3(120, 0.25, 40)  // Changed from -0.25 to +0.25 to flip the racket
        handleNode.eulerAngles.x = .pi / 2
        
        racketContainer.addChildNode(headNode)
        racketContainer.addChildNode(handleNode)
        
        let collisionBox = SCNBox(width: 0.25, height: 0.32, length: 0.1, chamferRadius: 0)
        racketContainer.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: collisionBox, options: nil))
        racketContainer.physicsBody?.categoryBitMask = 4
        racketContainer.physicsBody?.collisionBitMask = 1
        racketContainer.physicsBody?.contactTestBitMask = 1
        
        racketNode = racketContainer
        racketNode?.position = SCNVector3(0, 0, -2)
        scene.rootNode.addChildNode(racketNode!)
    }
    
    private func startAutoSpawn() {
        autoSpawnTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.spawnBall()
        }
    }
    
    // This is called every frame by the SceneKit renderer delegate
    func updateScene(atTime time: TimeInterval) {
        guard let racketNode = racketNode else { return }
        // Smoothly interpolate racket position to the target for less jitter
        racketNode.position = racketNode.position.lerp(to: targetRacketPosition, t: 0.3)
    }
    
    func updateRacketPosition(from joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint], swingSpeed: Double) {
        guard let rightWrist = joints[.rightWrist],
              let neck = joints[.neck],
              let root = joints[.root],
              rightWrist.confidence > 0.3,
              neck.confidence > 0.3,
              root.confidence > 0.3 else { return }
        
        // --- IMPROVED DEPTH LOGIC ---
        // Use body height to estimate user's distance from the camera
        let bodyHeight = abs(neck.location.y - root.location.y)
        let referenceHeight: CGFloat = 0.4 // Calibrated for a user ~2m away
        
        // Calculate a scale factor based on current vs reference height
        let distanceScale = referenceHeight / max(bodyHeight, 0.1)
        // Clamp the scale to prevent extreme values if tracking is lost or user is too close/far
        let clampedScale = min(max(distanceScale, 0.6), 2.2)
        
        // Map the scale to a Z-depth range. A larger scale means user is further away (more negative Z)
        let z = -1.0 - Float(clampedScale) * 10.1
        
        let x = Float(rightWrist.location.x - 0.5) * 4.0
        let y = Float(rightWrist.location.y - 0.5) * 4.0
        
        // Set the target position instead of moving the node directly
        targetRacketPosition = SCNVector3(x, y, z)
        currentSwingSpeed = Float(swingSpeed)
        
        if let rightElbow = joints[.rightElbow], rightElbow.confidence > 0.3 {
            let dx = rightWrist.location.x - rightElbow.location.x
            let dy = rightWrist.location.y - rightElbow.location.y
            let angle = atan2(dy, dx)
            racketNode?.eulerAngles = SCNVector3(0, 0, Float(angle) + 3 * .pi / 2)
        }
    }
    
    func spawnBall() {
        ballsSpawned += 1
        
        let ballNode: SCNNode
        
        if let ballURL = Bundle.main.url(forResource: "tennis_ball", withExtension: "usdz"),
           let ballScene = try? SCNScene(url: ballURL, options: nil) {
            ballNode = ballScene.rootNode.clone()
            ballNode.scale = SCNVector3(0.008, 0.008, 0.008)
        } else {
            let ballGeometry = SCNSphere(radius: 0.065)
            ballGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.89, green: 0.98, blue: 0.29, alpha: 1.0)
            ballNode = SCNNode(geometry: ballGeometry)
        }
        
        let spawnHeight = Float.random(in: 0.5...1.2)
        // Spawn the ball further back to give it travel time
        let spawnDepth = Float.random(in: -40.0...(-30.0))
        ballNode.position = SCNVector3(2.5, spawnHeight, spawnDepth)
        
        let sphereShape = SCNSphere(radius: 0.065)
        let physicsShape = SCNPhysicsShape(geometry: sphereShape, options: nil)
        ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        ballNode.physicsBody?.mass = 0.058
        ballNode.physicsBody?.restitution = 0.7
        ballNode.physicsBody?.friction = 0.5
        ballNode.physicsBody?.damping = 0.2
        ballNode.physicsBody?.categoryBitMask = 1
        ballNode.physicsBody?.collisionBitMask = 6 // Collide with floor and racket
        ballNode.physicsBody?.contactTestBitMask = 4 // Test contact with racket
        
        scene.rootNode.addChildNode(ballNode)
        ballNodes.append(ballNode)
        
        let velocityX = Float.random(in: -2.5...(-1.8))
        let velocityY = Float.random(in: -0.2...0.1)
        // --- FIX: ADD Z VELOCITY ---
        // Give the ball velocity towards the player (positive Z)
        let velocityZ = Float.random(in: 2.0...3.0)
        ballNode.physicsBody?.velocity = SCNVector3(velocityX, velocityY, velocityZ)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self, weak ballNode] in
            ballNode?.removeFromParentNode()
            if let ballNode = ballNode {
                self?.ballNodes.removeAll { $0 == ballNode }
            }
        }
    }
    
    func checkBallHit() -> Bool {
        guard let racketNode = racketNode else { return false }
        
        for (index, ball) in ballNodes.enumerated().reversed() {
            // Use the smoothly interpolated racket position for hit detection
            let distance = (ball.presentation.position - racketNode.presentation.position).length
            
            if distance < 0.4 && currentSwingSpeed > 1.0 {
                ballsHit += 1
                
                // --- IMPROVED HIT LOGIC ---
                // Define a clear direction to send the ball back into the scene
                let hitDirection = SCNVector3(
                    -0.5, // Sideways component
                    0.6,  // Upward lift
                    -1.2  // CRITICAL: Strong negative Z to send it away from the camera
                ).normalized
                
                ball.physicsBody?.velocity = SCNVector3.zero
                ball.physicsBody?.angularVelocity = SCNVector4.zero
                
                // Apply a stronger force for a more satisfying hit
                let hitForce = hitDirection * currentSwingSpeed * 18
                ball.physicsBody?.applyForce(hitForce, asImpulse: true)
                
                ball.physicsBody?.applyTorque(SCNVector4(1, 0, 0, currentSwingSpeed), asImpulse: true)
                
                print("✅ Ball hit! Speed: \(currentSwingSpeed) Distance: \(distance)")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    ball.removeFromParentNode()
                }
                ballNodes.remove(at: index)
                
                return true
            }
        }
        return false
    }
    
    deinit {
        autoSpawnTimer?.invalidate()
    }
}

// MARK: - Enhanced Swing Analyzer
class EnhancedSwingAnalyzer: SwingAnalyzer {
    @Published var currentSwingSpeed: Double = 0
    
    var enhancedSwingType: EnhancedSwingType {
        switch detectedSwingType {
        case .unknown: return .unknown
        case .forehand: return .forehand
        case .backhand: return .backhand
        }
    }
    
    enum EnhancedSwingType {
        case unknown, forehand, backhand
        
        var displayName: String {
            switch self {
            case .unknown: return "POSITION YOURSELF"
            case .forehand: return "FOREHAND READY"
            case .backhand: return "BACKHAND READY"
            }
        }
    }
    
    private var hitCount = 0
    
    func registerHit() {
        hitCount += 1
    }
    
    override func analyzeSwing(_ joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        super.analyzeSwing(joints)
        
        guard let rightWrist = joints[.rightWrist],
              let rightElbow = joints[.rightElbow],
              rightWrist.confidence > 0.4,
              rightElbow.confidence > 0.4 else { return }
        
        currentSwingSpeed = estimatedSpeed / 10.0
    }
}

// MARK: - Vector Extensions
extension SCNVector3 {
    static let zero = SCNVector3(0, 0, 0)
    
    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }
    
    static func * (vector: SCNVector3, scalar: Float) -> SCNVector3 {
        return SCNVector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }
    
    var length: Float {
        return sqrt(x*x + y*y + z*z)
    }
    
    var normalized: SCNVector3 {
        let len = length
        return len > 0 ? SCNVector3(x/len, y/len, z/len) : self
    }
    
    // Linear interpolation function for smooth motion
    func lerp(to vector: SCNVector3, t: Float) -> SCNVector3 {
        return SCNVector3(
            self.x + (vector.x - self.x) * t,
            self.y + (vector.y - self.y) * t,
            self.z + (vector.z - self.z) * t
        )
    }
}

extension SCNVector4 {
    static let zero = SCNVector4(0, 0, 0, 0)
}

extension SCNNode {
    func look(at target: SCNVector3, up: SCNVector3, localFront: SCNVector3) {
        let direction = (target - position).normalized
        let dotProduct = localFront.x * direction.x + localFront.y * direction.y + localFront.z * direction.z
        let angle = acos(dotProduct)
        let crossProduct = SCNVector3(
            localFront.y * direction.z - localFront.z * direction.y,
            localFront.z * direction.x - localFront.x * direction.z,
            localFront.x * direction.y - localFront.y * direction.x
        )
        rotation = SCNVector4(crossProduct.x, crossProduct.y, crossProduct.z, angle)
    }
}
