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
    
    // Enhanced session tracking
    private var sessionData: TennisSessionData?
    private var lastPhase: SwingAnalyzer.Phase = .ready
    private var lastSwingCount = 0
    private var lastFormScore = 0
    private var lastSpeed: Double = 0
    
    // Performance tracking
    private var averageFormScore: Double = 0
    private var swingFormScores: [Int] = []
    private var peakSpeed: Double = 0
    private var consistencyWindow: [Int] = []
    
    // Message management
    private var messageQueue: [PrioritizedMessage] = []
    private var isProcessingQueue = false
    private var recentMessages: [String] = []
    private let maxRecentMessages = 10
    
    private let minimumMessageGap: TimeInterval = 2.0
    private var lastMessageTime: Date = .distantPast
    private var lastTechniqueAdvice: Date = .distantPast
    
    init(agentId: String) {
        self.agentId = agentId
    }
    
    // MARK: - Start Session
    func startSession(
        with sessionData: TennisSessionData,
        style: TennisCoachingStyle = .proCoach
    ) async {
        guard !isEnabled else { return }
        
        configureAudioSession()
        
        self.sessionData = sessionData
        self.coachingStyle = style
        self.state = .warmup
        
        resetTracking()
        
        let initialMessage = """
            Ready to train \(sessionData.swingType.rawValue.lowercased()). 
            Stand sideways, 6 feet back. I'll guide you through each phase. 
            Focus on smooth rotation and full follow-through.
            """
        
        do {
            let config = ConversationConfig(
                agentOverrides: AgentOverrides(
                    prompt: """
                        \(style.voicePrompt)
                        
                        Coaching \(sessionData.playerName) on \(sessionData.swingType.rawValue).
                        Target: \(sessionData.targetSwings) quality swings.
                        
                        PHASES & CUES:
                        1. Preparation: Unit turn, split step
                        2. Backswing: Full shoulder rotation (65°+), hip-shoulder separation
                        3. Forward: Hips initiate, kinetic chain, accelerate
                        4. Contact: Extension, racquet face control
                        5. Follow-through: High finish, balance
                        
                        KEY METRICS:
                        - Hip-shoulder separation (X-factor): 30-45° optimal
                        - Swing timing: 0.7-1.3 seconds
                        - Form score: 80+ excellent, 65-79 good, <65 needs work
                        - Speed: 45+ mph good recreational level
                        
                        COACHING PRIORITIES:
                        1. Phase transitions (immediate)
                        2. Technique issues (form <70, missing mechanics)
                        3. Encouragement (good swings, progress)
                        4. Strategy tips (between swings)
                        
                        Keep responses 6-15 words. Be specific with technical cues.
                        Use the metrics provided to give actionable feedback.
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
            
            print("✅ Enhanced Tennis Coach active: \(style.rawValue)")
            
        } catch {
            print("❌ Failed to start voice coach: \(error)")
            state = .error("Failed to connect")
            isEnabled = false
        }
    }
    
    // MARK: - Enhanced Swing Processing
    func processSwingAnalysis(_ analyzer: SwingAnalyzer) async {
        guard isEnabled else { return }
        
        // Phase transitions with detailed feedback
        if analyzer.currentPhase != lastPhase {
            await handlePhaseChange(from: lastPhase, to: analyzer.currentPhase, analyzer: analyzer)
            lastPhase = analyzer.currentPhase
        }
        
        // Swing completion with analytics
        if analyzer.swingCount > lastSwingCount {
            await handleSwingComplete(analyzer)
            lastSwingCount = analyzer.swingCount
        }
        
        // Technique feedback during swing
        if shouldProvideTechniqueFeedback() {
            await provideTechniqueCues(analyzer)
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
            return
            
        case .preparation:
            message = "Set position. Shoulders turned, knees bent."
            priority = .technique
            
        case .backswing:
            message = "Coiling. Load on back foot."
            priority = .technique
            
        case .forward:
            message = "Uncoil! Drive hips first, then shoulders."
            priority = .critical
            
        case .contact:
            message = "Contact zone! Extend through."
            priority = .critical
            
        case .followThrough:
            message = "Follow through high and across body."
            priority = .technique
            
        case .complete:
            return
            
        case .loop:
            message = "Reset to ready position."
            priority = .info
        }
        
        await queueMessage(PrioritizedMessage(message, priority: priority))
    }
    
    private func handleSwingComplete(_ analyzer: SwingAnalyzer) async {
        let score = analyzer.formScore
        let speed = Int(analyzer.estimatedSpeed)
        
        // Track stats
        swingFormScores.append(score)
        if swingFormScores.count > 5 {
            averageFormScore = Double(swingFormScores.suffix(5).reduce(0, +)) / 5.0
        }
        
        if analyzer.estimatedSpeed > peakSpeed {
            peakSpeed = analyzer.estimatedSpeed
        }
        
        consistencyWindow.append(score)
        if consistencyWindow.count > 3 {
            consistencyWindow.removeFirst()
        }
        
        let remaining = (sessionData?.targetSwings ?? 20) - analyzer.swingCount
        
        // Build intelligent feedback
        var message = "Swing \(analyzer.swingCount). "
        
        // Performance feedback
        if score >= 85 {
            message += "Excellent form! \(score). "
            if speed > 45 {
                message += "Great speed: \(speed) mph."
            }
        } else if score >= 70 {
            message += "Good technique. Form \(score), speed \(speed) mph."
        } else {
            message += "Form needs work: \(score). "
            message += await getTechniqueAdvice(score: score)
        }
        
        // Progress check
        if remaining == 5 {
            message += " Final 5 swings - maintain quality."
        } else if remaining == 10 {
            let avgScore = Int(averageFormScore)
            message += " Halfway. Average form: \(avgScore)."
        }
        
        await queueMessage(PrioritizedMessage(message, priority: .critical))
        
        // Check consistency
        if consistencyWindow.count >= 3 {
            let variance = calculateVariance(consistencyWindow)
            if variance < 10 {
                await queueMessage(PrioritizedMessage(
                    "Great consistency! Keep this rhythm.",
                    priority: .motivation
                ))
            }
        }
    }
    
    private func getTechniqueAdvice(score: Int) async -> String {
        if score < 50 {
            return "Focus on full shoulder rotation and smooth acceleration."
        } else if score < 65 {
            return "Improve hip-shoulder separation and follow-through."
        } else {
            return "Work on timing and weight transfer."
        }
    }
    
    private func shouldProvideTechniqueFeedback() -> Bool {
        return Date().timeIntervalSince(lastTechniqueAdvice) > 12.0 && !isAgentSpeaking
    }
    
    private func provideTechniqueCues(_ analyzer: SwingAnalyzer) async {
        guard let tip = generateContextualTip(analyzer) else { return }
        
        lastTechniqueAdvice = Date()
        await queueMessage(PrioritizedMessage(tip, priority: .technique))
    }
    
    private func generateContextualTip(_ analyzer: SwingAnalyzer) -> String? {
        let formScore = analyzer.formScore
        
        if formScore > 0 && formScore < 65 {
            let tips = [
                "Remember: hips rotate before shoulders for power.",
                "Keep your eyes on contact point longer.",
                "Accelerate through contact, don't slow down.",
                "Finish with hand high above opposite shoulder.",
                "Load weight on back foot, transfer to front."
            ]
            return tips.randomElement()
        } else if lastSwingCount > 8 && averageFormScore < 75 {
            return "Between swings: visualize smooth, complete rotation."
        }
        
        return nil
    }
    
    private func calculateVariance(_ values: [Int]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let variance = values.reduce(0.0) { sum, value in
            sum + pow(Double(value) - mean, 2)
        } / Double(values.count)
        return sqrt(variance)
    }
    
    // MARK: - Message Queue Management
    func queueMessage(_ message: PrioritizedMessage) async {
        // Avoid repetition
        if recentMessages.contains(where: { $0.contains(message.content) || message.content.contains($0) }) {
            return
        }
        
        recentMessages.append(message.content)
        if recentMessages.count > maxRecentMessages {
            recentMessages.removeFirst()
        }
        
        // Priority insertion
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
    
    // MARK: - Control Methods
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
        averageFormScore = 0
        peakSpeed = 0
        swingFormScores.removeAll()
        consistencyWindow.removeAll()
        recentMessages.removeAll()
        messageQueue.removeAll()
        lastMessageTime = .distantPast
        lastTechniqueAdvice = .distantPast
    }
    
    // MARK: - Audio Configuration
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredIOBufferDuration(0.005)
            print("✅ Audio configured for voice coaching")
        } catch {
            print("❌ Audio setup failed: \(error)")
        }
    }
    
    private func resetAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ Audio reset failed: \(error)")
        }
    }
    
    // MARK: - End Session
    func endSession() async {
        guard let conversation = conversation else { return }
        
        if lastSwingCount > 0 {
            let avgScore = swingFormScores.isEmpty ? 0 : swingFormScores.reduce(0, +) / swingFormScores.count
            let final = """
                Session complete! \(lastSwingCount) swings. 
                Average form: \(avgScore). Peak speed: \(Int(peakSpeed)) mph. 
                Great work today!
                """
            await sendMessage(final)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
        }
        
        await conversation.endConversation()
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
