import AVFoundation
import Vision

/// Front camera frames turned into body joints with Apple Vision, on the device and without internet.
@MainActor
final class CameraPoseService: BodyPoseProviding {
    private let processor = PoseFrameProcessor()

    var captureSession: AVCaptureSession? { processor.session }

    func start(onFrame: @escaping @MainActor (PoseFrame) -> Void) async throws {
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw CPRCoachError.cameraDenied }
        try await processor.start(onFrame: onFrame)
    }

    func stop() {
        processor.stop()
    }
}

/// Owns the capture session and runs body-pose detection on a background queue.
private final class PoseFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    // Below this confidence the arm is too hidden to measure
    static let minConfidence = 0.3

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "mx.cruzroja.enlacevital.cpr-camera")
    private let request = VNDetectHumanBodyPoseRequest()
    private var onFrame: (@MainActor (PoseFrame) -> Void)?
    private var firstTimestamp: CMTime?
    private var isConfigured = false

    func start(onFrame: @escaping @MainActor (PoseFrame) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.configure()
                    self.onFrame = onFrame
                    self.firstTimestamp = nil
                    // startRunning blocks, so it runs on the camera queue
                    self.session.startRunning()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            self.onFrame = nil
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() throws {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            throw CPRCoachError.cameraUnavailable
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        guard session.canAddOutput(output) else { throw CPRCoachError.cameraUnavailable }

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        session.addInput(input)
        session.addOutput(output)
        if let connection = output.connection(with: .video) {
            // Upright, mirrored frames match what the preview shows, so Vision points line up with the screen
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
        output.setSampleBufferDelegate(self, queue: queue)
        session.commitConfiguration()
        isConfigured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let onFrame, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if firstTimestamp == nil { firstTimestamp = timestamp }
        let time = CMTimeGetSeconds(CMTimeSubtract(timestamp, firstTimestamp ?? timestamp))
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
        let joints = request.results?.first.flatMap { Self.joints(from: $0, size: size) }
        let frame = PoseFrame(time: time, joints: joints, imageSize: size)
        Task { @MainActor in onFrame(frame) }
    }

    // Converts Vision's normalized points (origin at the bottom left) to pixels of the upright image
    private static func joints(from observation: VNHumanBodyPoseObservation, size: CGSize) -> BodyJoints? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        func pixel(_ point: VNRecognizedPoint) -> CGPoint {
            CGPoint(x: point.location.x * size.width, y: (1 - point.location.y) * size.height)
        }

        func arm(_ shoulder: VNHumanBodyPoseObservation.JointName, _ elbow: VNHumanBodyPoseObservation.JointName,
                 _ wrist: VNHumanBodyPoseObservation.JointName, _ hip: VNHumanBodyPoseObservation.JointName) -> Arm? {
            guard let s = points[shoulder], let e = points[elbow], let w = points[wrist], let h = points[hip] else { return nil }
            return Arm(shoulder: pixel(s), elbow: pixel(e), wrist: pixel(w), hip: pixel(h),
                       visibility: Double(min(s.confidence, e.confidence, w.confidence, h.confidence)))
        }

        guard let left = arm(.leftShoulder, .leftElbow, .leftWrist, .leftHip),
              let right = arm(.rightShoulder, .rightElbow, .rightWrist, .rightHip) else { return nil }
        let joints = BodyJoints(left: left, right: right)
        return joints.bestArm.visibility >= minConfidence ? joints : nil
    }
}
