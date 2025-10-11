//
//  ChallengeView.swift
//  Spindra
//

import SwiftUI
import AVFoundation
import Combine

struct ChallengeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var poseEstimator = TennisPoseEstimator()
    @StateObject private var swingAnalyzer = SwingAnalyzer()
    @StateObject private var voiceCoach: TennisVoiceCoach
    @Environment(\.dismiss) var dismiss
    
    @State private var showingStylePicker = false
    @State private var selectedStyle: TennisCoachingStyle = .proCoach
    @State private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Get agent ID from Info.plist
        let agentId = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_AGENT_ID") as? String ?? ""
        _voiceCoach = StateObject(wrappedValue: TennisVoiceCoach(agentId: agentId))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera preview
            CameraPreviewView(session: poseEstimator.captureSession)
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
            
            // UI Overlay
            VStack {
                topBar
                Spacer()
                statsDisplay
                Spacer()
                voiceCoachControls
            }
        }
        .onAppear {
            setupSession()
        }
        .onDisappear {
            cleanupSession()
        }
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
    
    // MARK: - UI Components
    
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
                Text("FOREHAND CHALLENGE")
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
    
    private var statsDisplay: some View {
        VStack(spacing: 20) {
            // Swing counter
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
            
            // Speed indicator
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
            
            // Feedback
            VStack(spacing: 8) {
                Text(swingAnalyzer.feedback)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                if voiceCoach.isAgentSpeaking {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 12))
                        Text("Coach speaking...")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "C4D600"))
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
    }
    
    private var voiceCoachControls: some View {
        HStack(spacing: 20) {
            Button(action: {
                Task { await voiceCoach.toggleMute() }
            }) {
                Image(systemName: voiceCoach.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(voiceCoach.isMuted ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                    .clipShape(Circle())
            }
            
            Button(action: {
                Task {
                    await voiceCoach.provideTip("Remember: rotate your shoulders fully during the backswing for maximum power.")
                }
            }) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 60)
    }
    
    // MARK: - Setup & Cleanup
    
    private func setupSession() {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        poseEstimator.swingAnalyzer = swingAnalyzer
        poseEstimator.setupCamera()
        poseEstimator.startSession()
        
        Task {
            await startVoiceCoach(style: selectedStyle)
            
            // Feedback loop
            Timer.publish(every: 0.5, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    Task {
                        await voiceCoach.processSwingAnalysis(swingAnalyzer)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func cleanupSession() {
        poseEstimator.stopSession()
        Task {
            await voiceCoach.endSession()
        }
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

// MARK: - Coaching Style Picker
struct CoachingStylePicker: View {
    @Binding var selectedStyle: TennisCoachingStyle
    @Environment(\.dismiss) var dismiss
    let onStyleSelected: () -> Void
    
    var body: some View {
        NavigationView {
            List(TennisCoachingStyle.allCases, id: \.self) { style in
                Button(action: {
                    selectedStyle = style
                    dismiss()
                    onStyleSelected()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.rawValue)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text(styleDescription(style))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        if selectedStyle == style {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "C4D600"))
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.1))
            }
            .navigationTitle("Select Coach Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func styleDescription(_ style: TennisCoachingStyle) -> String {
        switch style {
        case .proCoach:
            return "Professional, technical guidance"
        case .enthusiast:
            return "Energetic and passionate"
        case .mentalGame:
            return "Focus on mindfulness and mental strength"
        case .technician:
            return "Analytical and detail-oriented"
        }
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
