//
//  HomeScreenView.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


import SwiftUI

struct HomeScreenView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var motion = MotionManager.shared
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // Tennis court background
            TennisCourtBackground()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    HeaderView()
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : -20)
                        .animation(.easeInOut(duration: 0.5).delay(0.1), value: isVisible)
                    
                    // Player Card
                    PlayerCard()
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 20)
                        .animation(.easeInOut(duration: 0.5).delay(0.2), value: isVisible)
                    
                    // Daily Training Card
                    DailyTrainingCard()
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 20)
                        .animation(.easeInOut(duration: 0.5).delay(0.3), value: isVisible)
                    
                    // Challenge Card
                    ChallengeCard()
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 20)
                        .animation(.easeInOut(duration: 0.5).delay(0.4), value: isVisible)
                    
                    // Talk to Nelly Card
                    TalkToNellyCard()
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : 20)
                        .animation(.easeInOut(duration: 0.5).delay(0.5), value: isVisible)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isVisible = true
            motion.startTracking()
        }
    }
}

// MARK: - Tennis Court Background
struct TennisCourtBackground: View {
    var body: some View {
        ZStack {
            // Base dark green
            Color(hex: "#1a3d2e")
                .ignoresSafeArea()
            
            // Court lines pattern
            Canvas { context, size in
                let lineColor = Color.white.opacity(0.1)
                
                // Horizontal lines
                for i in 0...8 {
                    let y = size.height * CGFloat(i) / 8
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(lineColor), lineWidth: 1)
                }
                
                // Vertical lines
                for i in 0...4 {
                    let x = size.width * CGFloat(i) / 4
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(lineColor), lineWidth: 1)
                }
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    var body: some View {
        HStack {
            Button {
                // Settings action
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Spacer()
            
            // Spindra logo text
            HStack(spacing: 4) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.tennisYellow)
                
                Text("Spindra")
                    .font(.custom("System", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button {
                // Notifications
            } label: {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
            }
        }
        .frame(width: 350)
    }
}

#Preview {
    HomeScreenView()
        .environmentObject(AppState())
}
