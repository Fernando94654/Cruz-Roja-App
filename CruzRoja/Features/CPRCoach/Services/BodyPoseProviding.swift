import AVFoundation
import Foundation

/// One processed camera frame.
struct PoseFrame: Sendable {
    let time: TimeInterval
    let joints: BodyJoints?
    let imageSize: CGSize
}

/// Camera failures with user-facing messages.
enum CPRCoachError: LocalizedError {
    case cameraDenied
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraDenied: "Permite el acceso a la cámara en Ajustes para usar el coach de RCP."
        case .cameraUnavailable: "No se pudo abrir la cámara de este dispositivo."
        }
    }
}

/// Source of body poses for the CPR coach.
@MainActor
protocol BodyPoseProviding: AnyObject {
    /// Camera session to preview, or nil when there is no real camera.
    var captureSession: AVCaptureSession? { get }
    /// Starts delivering frames until stop() is called.
    func start(onFrame: @escaping @MainActor (PoseFrame) -> Void) async throws
    func stop()
}

/// Synthetic rescuer pushing at a steady rate, for the simulator, previews and tests.
@MainActor
final class MockBodyPoseProvider: BodyPoseProviding {
    static let imageSize = CGSize(width: 720, height: 1280)

    var rate: Double
    private var task: Task<Void, Never>?

    init(rate: Double = 110) {
        self.rate = rate
    }

    var captureSession: AVCaptureSession? { nil }

    func start(onFrame: @escaping @MainActor (PoseFrame) -> Void) async throws {
        let start = Date()
        task = Task { [weak self] in
            while !Task.isCancelled, let self {
                let t = Date().timeIntervalSince(start)
                onFrame(PoseFrame(time: t, joints: Self.pose(at: t, rate: rate), imageSize: Self.imageSize))
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Side view of a kneeling rescuer whose shoulders move about 36 px per compression.
    nonisolated static func pose(at t: TimeInterval, rate: Double) -> BodyJoints {
        let push = 18 * sin(2 * .pi * rate / 60 * t)
        let near = Arm(shoulder: CGPoint(x: 420, y: 520 + push), elbow: CGPoint(x: 430, y: 700 + push / 2),
                       wrist: CGPoint(x: 440, y: 880), hip: CGPoint(x: 200, y: 760), visibility: 0.9)
        let far = Arm(shoulder: CGPoint(x: 400, y: 530 + push), elbow: CGPoint(x: 415, y: 705 + push / 2),
                      wrist: CGPoint(x: 435, y: 882), hip: CGPoint(x: 190, y: 765), visibility: 0.3)
        return BodyJoints(left: far, right: near)
    }
}
