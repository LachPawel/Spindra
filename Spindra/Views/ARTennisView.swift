import SwiftUI
import RealityKit
import ARKit
import Combine

struct ARTennisView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var arManager = ARTennisManager()
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
            ARViewContainer(arManager: arManager)
                .ignoresSafeArea()
            
            VStack {
                topBar
                Spacer()
                statsOverlay
                Spacer()
                controlButtons
            }
        }
        .onAppear {
            arManager.startSession()
            Task {
                await startVoiceCoach()
                setupFeedbackLoop()
            }
        }
        .onDisappear {
            arManager.stopSession()
            Task { await voiceCoach.endSession() }
        }
        .sheet(isPresented: $showingStylePicker) {
            CoachingStylePicker(selectedStyle: $selectedStyle) {
                Task {
                    await voiceCoach.endSession()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await startVoiceCoach()
                }
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: {
                Task {
                    await voiceCoach.endSession()
                    arManager.stopSession()
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
                Text("AR TENNIS TRAINER")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                if voiceCoach.isEnabled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
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
    
    private var statsOverlay: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(arManager.currentSwingType == .forehand ? Color.blue :
                          arManager.currentSwingType == .backhand ? Color.orange : Color.gray)
                    .frame(width: 12, height: 12)
                Text(arManager.currentSwingType.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
            
            HStack(spacing: 40) {
                VStack {
                    Text("\(arManager.swingsCompleted)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: "C4D600"))
                    Text("HITS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                VStack {
                    Text("\(arManager.accuracy)%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    Text("ACCURACY")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Text(arManager.feedback)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            Button(action: { arManager.spawnBall() }) {
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
                    .background(voiceCoach.isMuted ? Color.red : Color.green)
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 60)
    }
    
    private func startVoiceCoach() async {
        let sessionData = TennisSessionData(
            sessionTitle: "AR Tennis Practice",
            swingType: .forehand,
            targetSwings: 20,
            playerName: "Player"
        )
        await voiceCoach.startSession(with: sessionData, style: selectedStyle)
    }
    
    private func setupFeedbackLoop() {
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task {
                    await sendSwingFeedback()
                }
            }
            .store(in: &cancellables)
    }
    
    private func sendSwingFeedback() async {
        guard voiceCoach.isEnabled else { return }
        
        let message: String
        let priority: MessagePriority
        
        switch arManager.currentPhase {
        case .ready:
            return
        case .backswing:
            message = "Loading. Coil back."
            priority = .technique
        case .forward:
            message = "Accelerate through!"
            priority = .critical
        case .contact:
            message = "Contact! Follow through high."
            priority = .critical
        case .followThrough:
            return
        }
        
        await voiceCoach.queueMessage(PrioritizedMessage(message, priority: priority))
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arManager: ARTennisManager
    
    func makeUIView(context: Context) -> ARView {
        return arManager.arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - AR Tennis Manager
@MainActor
class ARTennisManager: ObservableObject {
    let arView: ARView
    private var bodyAnchor: AnchorEntity?
    private var racketEntity: ModelEntity?
    private var activeBalls: [ModelEntity] = []
    
    @Published var swingsCompleted = 0
    @Published var accuracy = 0
    @Published var feedback = "Position yourself in frame"
    @Published var currentSwingType: SwingType = .none
    @Published var swingSpeed: Float = 0
    @Published var currentPhase: SwingPhase = .ready
    
    private var lastHandPosition: SIMD3<Float>?
    private var handVelocity: SIMD3<Float> = .zero
    private var totalBalls = 0
    private var ballsHit = 0
    
    enum SwingType {
        case none, forehand, backhand
        
        var displayName: String {
            switch self {
            case .none: return "Ready"
            case .forehand: return "FOREHAND"
            case .backhand: return "BACKHAND"
            }
        }
    }
    
    enum SwingPhase {
        case ready, backswing, forward, contact, followThrough
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        arView = ARView(frame: .zero)
        setupAR()
    }
    
    private func setupAR() {
        let config = ARBodyTrackingConfiguration()
        arView.session.run(config)
        
        bodyAnchor = AnchorEntity(.body)
        arView.scene.addAnchor(bodyAnchor!)
        
        createRacket()
        
        arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.updateTracking()
        }.store(in: &cancellables)
    }
    
    private func createRacket() {
        let headMesh = MeshResource.generateBox(width: 0.28, height: 0.32, depth: 0.02)
        let handleMesh = MeshResource.generateBox(width: 0.05, height: 0.15, depth: 0.05)
        
        let racketMaterial = SimpleMaterial(color: .blue, isMetallic: true)
        let handleMaterial = SimpleMaterial(color: .brown, isMetallic: false)
        
        let head = ModelEntity(mesh: headMesh, materials: [racketMaterial])
        let handle = ModelEntity(mesh: handleMesh, materials: [handleMaterial])
        handle.position.y = -0.235
        
        racketEntity = ModelEntity()
        racketEntity?.addChild(head)
        racketEntity?.addChild(handle)
        
        bodyAnchor?.addChild(racketEntity!)
    }
    
    func spawnBall() {
        totalBalls += 1
        
        let ballMesh = MeshResource.generateSphere(radius: 0.065)
        let ballMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
        let ball = ModelEntity(mesh: ballMesh, materials: [ballMaterial])
        
        ball.position = SIMD3<Float>(
            Float.random(in: -0.5...0.5),
            1.2,
            -2.0
        )
        
        ball.collision = CollisionComponent(shapes: [.generateSphere(radius: 0.065)])
        ball.physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: .default,
            mode: .dynamic
        )
        
        bodyAnchor?.addChild(ball)
        activeBalls.append(ball)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            ball.removeFromParent()
            self?.activeBalls.removeAll { $0 == ball }
        }
        
        feedback = "Incoming ball!"
    }
    
    private func updateTracking() {
        guard let bodyAnchor = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARBodyAnchor }).first else {
            feedback = "Step back - full body needed"
            return
        }
        
        let skeleton = bodyAnchor.skeleton
        
        guard let rightHandTransform = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "right_hand_joint")) else {
            return
        }
        
        let combinedTransform = matrix_multiply(bodyAnchor.transform, rightHandTransform)
        let handPosition = SIMD3<Float>(combinedTransform.columns.3.x,
                                        combinedTransform.columns.3.y,
                                        combinedTransform.columns.3.z)
        
        racketEntity?.position = handPosition
        
        if let lastPos = lastHandPosition {
            handVelocity = (handPosition - lastPos) * 60
            swingSpeed = length(handVelocity)
        }
        lastHandPosition = handPosition
        
        detectSwingTypeAndPhase(skeleton: skeleton, bodyAnchor: bodyAnchor)
        checkBallCollisions(racketPosition: handPosition)
        
        if totalBalls > 0 {
            accuracy = Int((Float(ballsHit) / Float(totalBalls)) * 100)
        }
    }
    
    private func detectSwingTypeAndPhase(skeleton: ARSkeleton3D, bodyAnchor: ARBodyAnchor) {
        guard let rightShoulderTransform = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "right_shoulder_1_joint")),
              let leftShoulderTransform = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "left_shoulder_1_joint")),
              let rightHandTransform = skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: "right_hand_joint")) else {
            return
        }
        
        let rightShoulder = matrix_multiply(bodyAnchor.transform, rightShoulderTransform).columns.3
        let leftShoulder = matrix_multiply(bodyAnchor.transform, leftShoulderTransform).columns.3
        let rightHand = matrix_multiply(bodyAnchor.transform, rightHandTransform).columns.3
        
        let shoulderMidpoint = (rightShoulder + leftShoulder) / 2
        let handRelativeX = rightHand.x - shoulderMidpoint.x
        
        if abs(handRelativeX) > 0.2 {
            currentSwingType = handRelativeX > 0 ? .forehand : .backhand
        }
        
        if swingSpeed > 2.5 && currentPhase == .backswing {
            currentPhase = .forward
            feedback = "Accelerating!"
        } else if swingSpeed > 3.5 && currentPhase == .forward {
            currentPhase = .contact
            feedback = "Contact zone!"
        } else if swingSpeed < 1.0 && currentPhase != .ready {
            currentPhase = .followThrough
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.currentPhase = .ready
                self.feedback = "Ready for next ball"
            }
        } else if swingSpeed < 0.5 && rightHand.y < shoulderMidpoint.y {
            currentPhase = .backswing
        }
    }
    
    private func checkBallCollisions(racketPosition: SIMD3<Float>) {
        for (index, ball) in activeBalls.enumerated().reversed() {
            let distance = length(ball.position - racketPosition)
            
            if distance < 0.2 && swingSpeed > 2.0 {
                ballsHit += 1
                swingsCompleted += 1
                
                let hitDirection = normalize(handVelocity)
                let impulse = hitDirection * swingSpeed * 0.5
                ball.addForce(impulse, relativeTo: nil)
                
                feedback = "Great hit! \(Int(swingSpeed * 10)) mph"
                SoundManager.shared.playSuccessSound()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    ball.removeFromParent()
                }
                activeBalls.remove(at: index)
            }
        }
    }
    
    func startSession() {
        feedback = "Get ready - full body in frame"
        arView.session.run(ARBodyTrackingConfiguration())
    }
    
    func stopSession() {
        arView.session.pause()
    }
}
