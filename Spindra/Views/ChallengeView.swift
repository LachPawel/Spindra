//
//  ChallengeView.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


//
//  ChallengeView.swift
//  Spindra
//

import SwiftUI
import AVFoundation

struct ChallengeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var poseEstimator = TennisPoseEstimator()
    @StateObject private var swingAnalyzer = SwingAnalyzer()
    @Environment(\.dismiss) var dismiss
    
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
                // Top bar
                HStack {
                    Button(action: {
                        poseEstimator.stopSession()
                        appState.currentScreen = .home
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("FOREHAND CHALLENGE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Balance spacer
                    Color.clear
                        .frame(width: 56, height: 56)
                }
                .padding(.horizontal)
                .padding(.top, 60)
                
                Spacer()
                
                // Stats Display
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
                    Text(swingAnalyzer.feedback)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            poseEstimator.swingAnalyzer = swingAnalyzer
            poseEstimator.setupCamera()
            poseEstimator.startSession()
        }
        .onDisappear {
            poseEstimator.stopSession()
        }
    }
}

// Camera preview wrapper
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
