//
//  TennisVoiceCoach.swift
//  Spindra
//

import Combine
import ElevenLabs
import SwiftUI
import AVFoundation

enum TennisCoachingStyle: String, CaseIterable {
    case proCoach = "Pro Coach"
    case enthusiast = "Tennis Enthusiast"
    case mentalGame = "Mental Game Coach"
    case technician = "Technical Coach"
    
    var voicePrompt: String {
        switch self {
        case .proCoach:
            return """
                You are a professional tennis coach. Focused, technical, encouraging.
                Use proper tennis terminology. Brief responses, 8-12 words max.
                Call the player by name. Emphasize technique and form.
                """
        case .enthusiast:
            return """
                You are an energetic tennis enthusiast! Passionate, positive, fun!
                Love the sport and show it. Make every swing exciting.
                Use phrases like "Beautiful!", "That's the sweet spot!", "Feel that power!"
                """
        case .mentalGame:
            return """
                You are a tennis mental game coach. Calm, focused, mindful.
                Emphasize breathing, visualization, mental preparation.
                Help with focus and confidence. Use calming language.
                """
        case .technician:
            return """
                You are a technical tennis analyst. Precise, analytical, detailed.
                Focus on biomechanics, angles, timing. Use specific measurements.
                Professional and informative. Break down each swing phase.
                """
        }
    }
}

struct TennisSessionData {
    let sessionTitle: String
    let swingType: TennisSwing.SwingType
    let targetSwings: Int
    let playerName: String
}

enum VoiceCoachState: Equatable {
    case idle
    case warmup
    case active
    case paused
    case complete
    case error(String)
    
    static func == (lhs: VoiceCoachState, rhs: VoiceCoachState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.warmup, .warmup), (.active, .active),
             (.paused, .paused), (.complete, .complete):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

enum MessagePriority: Int {
    case critical = 0    // Phase changes, completions
    case technique = 1   // Form feedback
    case motivation = 2  // Encouragement
    case info = 3        // General updates
}

struct PrioritizedMessage {
    let content: String
    let priority: MessagePriority
    let timestamp: Date
    let id: String
    
    init(_ content: String, priority: MessagePriority) {
        self.content = content
        self.priority = priority
        self.timestamp = Date()
        self.id = UUID().uuidString
    }
}

@MainActor
class TennisVoiceCoach: ObservableObject {
    @Published var state: VoiceCoachState = .idle
    @Published var isEnabled: Bool = false
    @Published var isMuted: Bool = false
    @Published var conversation: Conversation?
    @Published var lastMessage: String = ""
    @Published var isAgentSpeaking: Bool = false
    @Published var coachingStyle: TennisCoachingStyle = .proCoach
    
    private let agentId: String
    private var cancellables = Set<AnyCancellable>()
    
    // Session tracking
    private var sessionData: TennisSessionData?
    private var lastPhase: SwingAnalyzer.Phase = .ready
    private var lastSwingCount = 0
    private var lastFormScore = 0
    private var lastSpeed: Double = 0
    
    // Message management
    private var messageQueue: [PrioritizedMessage] = []
    private var isProcessingQueue = false
    private var recentMessages: [String] = []
    private let maxRecentMessages = 8
    
    private let minimumMessageGap: TimeInterval = 2.5
    private var lastMessageTime: Date = .distantPast
    
    init(agentId: String) {
        self.agentId = agentId
    }
    
    // MARK: - Start Session
    func startSession(
        with sessionData: TennisSessionData,
        style: TennisCoachingStyle = .proCoach
    ) async {
        guard !isEnabled else { return }
        
        // Configure audio session BEFORE starting conversation
        configureAudioSession()
        
        self.sessionData = sessionData
        self.coachingStyle = style
        self.state = .warmup
        
        resetTracking()
        
        let initialMessage = "Ready to work on your \(sessionData.swingType.rawValue.lowercased())? Position yourself sideways to the camera, about 6 feet back. Let's see your form."
        
        do {
            let config = ConversationConfig(
                agentOverrides: AgentOverrides(
                    prompt: """
                        \(style.voicePrompt)
                        
                        You are coaching \(sessionData.playerName) on their \(sessionData.swingType.rawValue).
                        Target: \(sessionData.targetSwings) quality swings.
                        
                        SWING PHASES: Ready → Preparation → Backswing → Forward → Contact → Follow-through → Complete
                        
                        Focus areas:
                        - Shoulder rotation (key indicator of power)
                        - Hip rotation and weight transfer
                        - Smooth acceleration through contact
                        - Full follow-through
                        - Consistent timing and rhythm
                        
                        Respond to technical data about phases, form scores, and speed.
                        Be encouraging but focus on technique improvement.
                        """,
                    firstMessage: initialMessage
                ),
                conversationOverrides: ConversationOverrides(
                    textOnly: false
                )
            )
            
            conversation = try await ElevenLabs.startConversation(
                agentId: agentId,
                config: config
            )
            
            setupObservers()
            
            state = .active
            isEnabled = true
            
            print("✅ Tennis Voice Coach online: \(style.rawValue)")
            
        } catch {
            print("❌ Failed to start voice coach: \(error)")
            state = .error("Failed to connect")
            isEnabled = false
        }
    }
    
    // MARK: - Process Swing Feedback
    func processSwingAnalysis(_ analyzer: SwingAnalyzer) async {
        guard isEnabled else { return }
        
        // Phase transitions
        if analyzer.currentPhase != lastPhase {
            await handlePhaseChange(from: lastPhase, to: analyzer.currentPhase, analyzer: analyzer)
            lastPhase = analyzer.currentPhase
        }
        
        // Swing completion
        if analyzer.swingCount > lastSwingCount {
            await handleSwingComplete(analyzer)
            lastSwingCount = analyzer.swingCount
        }
        
        // Form score changes
        if analyzer.formScore != lastFormScore && analyzer.formScore > 0 {
            await handleFormScoreUpdate(analyzer)
            lastFormScore = analyzer.formScore
        }
    }
    
    private func handlePhaseChange(
        from oldPhase: SwingAnalyzer.Phase,
        to newPhase: SwingAnalyzer.Phase,
        analyzer: SwingAnalyzer
    ) async {
        let message: String
        let priority: MessagePriority
        
        switch newPhase {
        case .ready:
            return // Skip ready phase messages
        case .preparation:
            message = "Phase: Preparation. Get set."
            priority = .info
        case .backswing:
            message = "Phase: Backswing. Coil those shoulders."
            priority = .technique
        case .forward:
            message = "Phase: Forward swing. Accelerate!"
            priority = .critical
        case .contact:
            message = "Phase: Contact zone!"
            priority = .critical
        case .followThrough:
            message = "Phase: Follow through. Complete the motion."
            priority = .technique
        case .complete:
            return // Handled by swing complete
        }
        
        await queueMessage(PrioritizedMessage(message, priority: priority))
    }
    
    private func handleSwingComplete(_ analyzer: SwingAnalyzer) async {
        let remaining = (sessionData?.targetSwings ?? 20) - analyzer.swingCount
        let speed = Int(analyzer.estimatedSpeed)
        let score = analyzer.formScore
        
        let message: String
        if remaining <= 3 {
            message = "Swing \(analyzer.swingCount)! \(remaining) more to go! Speed: \(speed) mph, Form: \(score)."
        } else if remaining <= 10 {
            message = "That's \(analyzer.swingCount). Form score: \(score). Speed: \(speed) mph."
        } else {
            message = "Good swing. Number \(analyzer.swingCount) complete."
        }
        
        await queueMessage(PrioritizedMessage(message, priority: .critical))
    }
    
    private func handleFormScoreUpdate(_ analyzer: SwingAnalyzer) async {
        let score = analyzer.formScore
        let message: String
        
        if score >= 90 {
            message = "Excellent form! Score: \(score). Keep this quality."
        } else if score >= 75 {
            message = "Good technique. Score: \(score)."
        } else if score < 60 {
            message = "Form score: \(score). Focus on smooth acceleration and full rotation."
        } else {
            return // Skip medium scores to avoid spam
        }
        
        await queueMessage(PrioritizedMessage(message, priority: .technique))
    }
    
    // MARK: - Message Queue
    private func queueMessage(_ message: PrioritizedMessage) async {
        if recentMessages.contains(message.content) {
            return
        }
        
        recentMessages.append(message.content)
        if recentMessages.count > maxRecentMessages {
            recentMessages.removeFirst()
        }
        
        let insertIndex = messageQueue.firstIndex { $0.priority.rawValue > message.priority.rawValue } ?? messageQueue.count
        messageQueue.insert(message, at: insertIndex)
        
        await processMessageQueue()
    }
    
    private func processMessageQueue() async {
        guard !isProcessingQueue, !isAgentSpeaking, !messageQueue.isEmpty else { return }
        
        isProcessingQueue = true
        defer { isProcessingQueue = false }
        
        let message = messageQueue.removeFirst()
        
        let timeSinceLastMessage = Date().timeIntervalSince(lastMessageTime)
        if timeSinceLastMessage < minimumMessageGap {
            let waitTime = minimumMessageGap - timeSinceLastMessage
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        await sendMessage(message.content)
    }
    
    private func sendMessage(_ message: String) async {
        guard let conversation = conversation else { return }
        
        do {
            try await conversation.sendMessage(message)
            lastMessage = message
            lastMessageTime = Date()
            print("🎾 Coach: \(message)")
        } catch {
            print("❌ Failed to send message: \(error)")
        }
    }
    
    // MARK: - Control
    func toggleMute() async {
        guard let conversation = conversation else { return }
        try? await conversation.toggleMute()
        isMuted = conversation.isMuted
    }
    
    func provideTip(_ tip: String) async {
        await queueMessage(PrioritizedMessage(tip, priority: .technique))
    }
    
    private func resetTracking() {
        lastPhase = .ready
        lastSwingCount = 0
        lastFormScore = 0
        lastSpeed = 0
        recentMessages.removeAll()
        messageQueue.removeAll()
        lastMessageTime = .distantPast
    }
    
    // MARK: - Audio Configuration
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Use playAndRecord category for bidirectional audio
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Set preferred sample rate and buffer duration for better quality
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            print("✅ Audio session configured for voice coach")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    private func resetAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("✅ Audio session reset")
        } catch {
            print("❌ Failed to reset audio: \(error)")
        }
    }
    
    // MARK: - End Session
    func endSession() async {
        guard let conversation = conversation else { return }
        
        if lastSwingCount > 0 {
            let final = "Session complete! Total swings: \(lastSwingCount). Great work today."
            await sendMessage(final)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        
        await conversation.endConversation()
        
        // Notify SoundManager that voice coach is ending
        SoundManager.shared.setVoiceCoachActive(false)
        
        resetAudioSession()
        
        self.conversation = nil
        isEnabled = false
        state = .idle
        cancellables.removeAll()
        messageQueue.removeAll()
    }
    
    // MARK: - Observers
    private func setupObservers() {
        guard let conversation = conversation else { return }
        
        conversation.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle: self?.state = .idle
                case .connecting: self?.state = .warmup
                case .active: self?.state = .active
                case .ended:
                    self?.state = .idle
                    Task { await self?.endSession() }
                case .error(let error):
                    self?.state = .error(error.localizedDescription)
                }
            }
            .store(in: &cancellables)
        
        conversation.$agentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] agentState in
                guard let self = self else { return }
                let speaking = (agentState == .speaking)
                
                if self.isAgentSpeaking != speaking {
                    self.isAgentSpeaking = speaking
                    if !speaking {
                        Task { await self.processMessageQueue() }
                    }
                }
            }
            .store(in: &cancellables)
    }
}
