import Foundation
import Observation

/// State and actions of the live CPR coach.
@MainActor
@Observable
final class CPRCoachViewModel {
    private(set) var count = 0
    private(set) var rate: Double?
    private(set) var armsStraight: Bool?
    private(set) var joints: BodyJoints?
    private(set) var imageSize = MockBodyPoseProvider.imageSize
    private(set) var elapsed: TimeInterval = 0
    private(set) var message: String?
    private(set) var isRunning = false
    var summary: CPRSessionSummary?
    var errorMessage: String?

    let config: CPRConfig
    let provider: BodyPoseProviding
    @ObservationIgnored private let speech: SpeechSynthesizing
    @ObservationIgnored private var counter: CompressionCounter
    @ObservationIgnored private var policy: FeedbackPolicy
    @ObservationIgnored private var stats: SessionStats
    @ObservationIgnored private var previousTime: TimeInterval = 0
    @ObservationIgnored private var messageTime: TimeInterval?

    init(provider: BodyPoseProviding, speech: SpeechSynthesizing, config: CPRConfig = CPRConfig()) {
        self.provider = provider
        self.speech = speech
        self.config = config
        counter = CompressionCounter(config: config)
        policy = FeedbackPolicy(config: config)
        stats = SessionStats(config: config)
    }

    /// True while the rate is inside the 100-120 per minute target.
    var isRateInRange: Bool {
        guard let rate else { return false }
        return (config.targetMinRate...config.targetMaxRate).contains(rate)
    }

    /// Starts the camera and a new session.
    func start() async {
        guard !isRunning else { return }
        counter = CompressionCounter(config: config)
        policy = FeedbackPolicy(config: config)
        stats = SessionStats(config: config)
        previousTime = 0
        messageTime = nil
        count = 0
        rate = nil
        message = nil
        summary = nil
        isRunning = true
        do {
            try await provider.start { [weak self] frame in self?.handle(frame) }
        } catch {
            isRunning = false
            errorMessage = error.localizedDescription
        }
    }

    /// Stops the camera and builds the session summary.
    func finish() {
        guard isRunning else { return }
        provider.stop()
        speech.stop()
        isRunning = false
        summary = stats.summary(count: counter.count)
    }

    /// Updates the counter, the feedback and the overlay with one frame.
    func handle(_ frame: PoseFrame) {
        let t = frame.time
        elapsed = t
        imageSize = frame.imageSize
        joints = frame.joints

        var straight: Bool?
        var currentRate = counter.rate(at: t)
        if let joints = frame.joints {
            let arm = joints.bestArm
            straight = armAngle(shoulder: arm.shoulder, elbow: arm.elbow, wrist: arm.wrist) >= config.straightArmDegrees
            currentRate = counter.update(time: t, y: joints.shouldersY, torsoLength: joints.torsoLength).rate
        }
        armsStraight = straight
        rate = currentRate
        count = counter.count

        stats.update(dt: max(0, t - previousTime), rate: currentRate, armsStraight: straight)
        previousTime = t

        if let feedback = policy.decide(at: t, counter: counter, armsStraight: straight) {
            speech.speak(feedback.rawValue)
            message = feedback.rawValue
            messageTime = t
        } else if let messageTime, t - messageTime > 3 {
            message = nil
        }
    }
}
