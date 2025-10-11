//
//  PlayerCard.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


import SwiftUI

// MARK: - Player Card (FIFA-style)
struct PlayerCard: View {
    @ObservedObject private var motion = MotionManager.shared
    
    var body: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#87CEEB"),
                            Color(hex: "#4A90E2")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 0) {
                // Flag and Share button
                HStack {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        // Share action
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12))
                            Text("Share")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.tennisYellow)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Player name and stats
                VStack(spacing: 8) {
                    Text("Evelinse Nadal")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Stats row
                    HStack(spacing: 32) {
                        VStack(spacing: 4) {
                            Text("2845")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text("POINTS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        VStack(spacing: 4) {
                            Text("34")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text("WINS")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        VStack(spacing: 4) {
                            Text("98%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text("PRECISION")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 350, height: 240)
        .rotation3DEffect(
            .degrees(motion.pitch * 4),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(motion.roll * 4),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.easeOut(duration: 0.3), value: motion.pitch)
        .animation(.easeOut(duration: 0.3), value: motion.roll)
    }
}

// MARK: - Daily Training Card
struct DailyTrainingCard: View {
    @ObservedObject private var motion = MotionManager.shared
    
    var body: some View {
        Button {
            // Open daily training
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                // Animated background lines
                AnimatedCourtLines()
                    .cornerRadius(16)
                    .opacity(0.3)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Text("Daily Training")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.tennisYellow)
                            Text("+150")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.tennisYellow)
                        }
                    }
                    
                    // Description
                    Text("Execute all daily trainings to earn your points and climb the ranks.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(2)
                    
                    // Progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("2/4")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.tennisYellow)
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color.tennisYellow)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        Text("Daily Trainings Done")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .frame(width: 350)
        }
        .rotation3DEffect(
            .degrees(motion.pitch * 4),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(motion.roll * 4),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.easeOut(duration: 0.3), value: motion.pitch)
        .animation(.easeOut(duration: 0.3), value: motion.roll)
    }
}

// MARK: - Challenge Card
struct ChallengeCard: View {
    @ObservedObject private var motion = MotionManager.shared
    
    var body: some View {
        Button {
            // Open challenge
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Text("Challenge")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.tennisYellow)
                            Text("+150")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.tennisYellow)
                        }
                    }
                    
                    // Description
                    Text("Challenge your other players and see who reigns supreme.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(2)
                    
                    // Progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("1/4")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.tennisYellow)
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color.tennisYellow)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "figure.tennis")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        Text("Today's Challenges Done")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .frame(width: 350)
        }
        .rotation3DEffect(
            .degrees(motion.pitch * 4),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(motion.roll * 4),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.easeOut(duration: 0.3), value: motion.pitch)
        .animation(.easeOut(duration: 0.3), value: motion.roll)
    }
}

// MARK: - Talk to Nelly Card
struct TalkToNellyCard: View {
    @ObservedObject private var motion = MotionManager.shared
    
    var body: some View {
        Button {
            // Open chat with Nelly
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FF6B6B"),
                                Color(hex: "#EE5A6F")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Talk to Nelly")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("She will tell you everything you need to know about world of tennis.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(2)
                        
                        // Better Call Nelly text
                        Text("BETTER CALL")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black.opacity(0.3))
                            .italic()
                        
                        Text("Nelly")
                            .font(.system(size: 48, weight: .black))
                            .foregroundColor(Color(hex: "#FF3B3B"))
                            .italic()
                            .offset(y: -20)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.tennisYellow)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "phone.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .padding(20)
            }
            .frame(width: 350, height: 200)
        }
        .rotation3DEffect(
            .degrees(motion.pitch * 4),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(motion.roll * 4),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.easeOut(duration: 0.3), value: motion.pitch)
        .animation(.easeOut(duration: 0.3), value: motion.roll)
    }
}

// MARK: - Animated Court Lines Background
struct AnimatedCourtLines: View {
    @State private var time: Double = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = time + timeline.date.timeIntervalSinceReferenceDate * 0.3
                
                // Draw animated diagonal lines
                for i in 0..<20 {
                    let seed = Double(i) * 2.0
                    let speed = 40.0 + sin(seed) * 20.0
                    let cycleDuration = size.width + 200.0
                    let progress = (t * speed + seed * 60.0).truncatingRemainder(dividingBy: cycleDuration)
                    
                    let x = -100.0 + progress
                    let y = -50.0 + progress * 0.7
                    
                    let lineLength = 30.0 + sin(seed * 1.5) * 20.0
                    let endX = x + lineLength
                    let endY = y + lineLength * 0.7
                    
                    if x < size.width + 50 && y < size.height + 50 {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: endX, y: endY))
                        
                        let opacity = 0.2
                        
                        context.stroke(
                            path,
                            with: .color(Color.white.opacity(opacity)),
                            style: StrokeStyle(lineWidth: 1.0, lineCap: .round)
                        )
                    }
                }
            }
            .onAppear { withAnimation(.linear(duration: 1000)) { time = 0 } }
        }
        .allowsHitTesting(false)
    }
}
