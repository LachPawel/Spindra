//
//  SwingSkeletonView.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


//
//  SwingSkeletonView.swift
//  Spindra
//

import SwiftUI
import Vision

struct SwingSkeletonView: View {
    let joints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    let size: CGSize
    let phase: SwingAnalyzer.Phase
    
    private var color: Color {
        switch phase {
        case .ready: return .gray
        case .preparation: return .yellow
        case .backswing: return .orange
        case .forward, .contact: return Color(hex: "C4D600")
        case .followThrough: return .green
        case .complete: return .green
        }
    }
    
    var body: some View {
        Canvas { context, size in
            // Draw skeleton bones
            drawBone(context, from: .neck, to: .rightShoulder)
            drawBone(context, from: .neck, to: .leftShoulder)
            drawBone(context, from: .rightShoulder, to: .rightElbow)
            drawBone(context, from: .rightElbow, to: .rightWrist)
            drawBone(context, from: .leftShoulder, to: .leftElbow)
            drawBone(context, from: .leftElbow, to: .leftWrist)
            
            drawBone(context, from: .neck, to: .root)
            drawBone(context, from: .root, to: .rightHip)
            drawBone(context, from: .root, to: .leftHip)
            drawBone(context, from: .rightHip, to: .rightKnee)
            drawBone(context, from: .rightKnee, to: .rightAnkle)
            drawBone(context, from: .leftHip, to: .leftKnee)
            drawBone(context, from: .leftKnee, to: .leftAnkle)
            
            // Draw joints
            for (_, point) in joints where point.confidence > 0.3 {
                let converted = convertPoint(point.location, size: size)
                context.fill(
                    Circle().path(in: CGRect(x: converted.x - 5, y: converted.y - 5, width: 10, height: 10)),
                    with: .color(color)
                )
            }
        }
    }
    
    private func drawBone(
        _ context: GraphicsContext,
        from: VNHumanBodyPoseObservation.JointName,
        to: VNHumanBodyPoseObservation.JointName
    ) {
        guard let fromPoint = joints[from],
              let toPoint = joints[to],
              fromPoint.confidence > 0.3,
              toPoint.confidence > 0.3 else { return }
        
        let start = convertPoint(fromPoint.location, size: size)
        let end = convertPoint(toPoint.location, size: size)
        
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        context.stroke(path, with: .color(color), lineWidth: 3)
    }
    
    private func convertPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        return CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )
    }
}
