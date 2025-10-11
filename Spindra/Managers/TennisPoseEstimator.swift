//
//  TennisPoseEstimator.swift
//  Spindra
//
//  Created by Pawel Kowalewski on 11/10/2025.
//


//
//  TennisPoseEstimator.swift
//  Spindra
//

import AVFoundation
import Vision
import Combine
import SwiftUI

class TennisPoseEstimator: NSObject, ObservableObject {
    @Published var detectedJoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint] = [:]
    @Published var isDetectingPerson: Bool = false
    
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "tennis.pose.processing")
    
    var swingAnalyzer: SwingAnalyzer?
    
    func setupCamera() {
        captureSession.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("❌ Camera setup failed")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = true
        }
    }
    
    func startSession() {
        processingQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}

// MARK: - Video Processing
extension TennisPoseEstimator: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let observation = request.results?.first as? VNHumanBodyPoseObservation else {
                DispatchQueue.main.async {
                    self?.isDetectingPerson = false
                }
                return
            }
            
            self?.processBodyPose(observation)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    private func processBodyPose(_ observation: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.detectedJoints = recognizedPoints
            self?.isDetectingPerson = true
            self?.swingAnalyzer?.analyzeSwing(recognizedPoints)
        }
    }
}
