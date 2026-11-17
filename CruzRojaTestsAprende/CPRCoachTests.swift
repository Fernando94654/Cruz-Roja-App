import Foundation
import Testing
@testable import CruzRoja

private let fps = 30.0
private let torso = 0.3

// Synthetic shoulder heights on a 30 fps camera: pushes of 0.1 torso lengths, noise and slow body drift
private func compressions(bpm: Double, seconds: Double, noise: Double = 0.003, drift: Double = 0, seed: UInt64 = 1) -> [(Double, Double)] {
    var rng = SeededGenerator(seed: seed)
    return (0..<Int(seconds * fps)).map { i in
        let t = Double(i) / fps
        let y = 0.5 + 0.015 * sin(2 * .pi * bpm / 60 * t) + drift * sin(2 * .pi * 0.15 * t) + rng.gaussian() * noise
        return (t, y)
    }
}

@discardableResult
private func run(_ counter: CompressionCounter, _ samples: [(Double, Double)], torsoJitter: Double = 0) -> CounterUpdate? {
    var rng = SeededGenerator(seed: 2)
    var last: CounterUpdate?
    for (t, y) in samples {
        last = counter.update(time: t, y: y, torsoLength: torso * (1 + rng.uniform(-torsoJitter, torsoJitter)))
    }
    return last
}

private func isClose(_ value: Double?, _ expected: Double, tolerance: Double = 0.05) -> Bool {
    guard let value else { return false }
    return abs(value - expected) <= tolerance * expected
}

// Deterministic random numbers so the tests always see the same noise
private struct SeededGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }

    mutating func uniform(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }

    mutating func gaussian() -> Double {
        sqrt(-2 * log(max(next(), 1e-12))) * cos(2 * .pi * next())
    }
}

@Suite("CPR compression counter")
struct CompressionCounterTests {
    @Test(arguments: [80.0, 100, 110, 120, 140])
    func rateIsWithinFivePercent(bpm: Double) {
        let update = run(CompressionCounter(), compressions(bpm: bpm, seconds: 30))
        #expect(isClose(update?.rate, bpm))
    }

    @Test(arguments: [100.0, 120])
    func countsEveryCompression(bpm: Double) {
        let counter = CompressionCounter()
        run(counter, compressions(bpm: bpm, seconds: 30))
        #expect(abs(Double(counter.count) - bpm / 2) <= 1)
    }

    @Test func ignoresSmallMovements() {
        let counter = CompressionCounter()
        for i in 0..<Int(10 * fps) {
            let t = Double(i) / fps
            _ = counter.update(time: t, y: 0.5 + 0.0015 * sin(2 * .pi * 2 * t), torsoLength: torso)
        }
        #expect(counter.count == 0)
    }

    @Test(arguments: [90.0, 110, 130])
    func handlesBodyDriftAndTorsoJitter(bpm: Double) {
        let counter = CompressionCounter()
        let update = run(counter, compressions(bpm: bpm, seconds: 30, drift: 0.03), torsoJitter: 0.25)
        #expect(isClose(update?.rate, bpm))
        #expect(abs(Double(counter.count) - bpm / 2) <= 3)
    }

    @Test func alternatingStrongAndWeakPushesKeepTheRealRate() {
        let f = 110.0 / 60
        let samples = (0..<Int(20 * fps)).map { i -> (Double, Double) in
            let t = Double(i) / fps
            return (t, 0.5 + 0.015 * sin(2 * .pi * f * t) + 0.009 * sin(.pi * f * t))
        }
        #expect(isClose(run(CompressionCounter(), samples)?.rate, 110))
    }

    @Test func pauseClearsTheRateAndAsksToContinue() {
        let counter = CompressionCounter()
        run(counter, compressions(bpm: 110, seconds: 10))
        let t = 13.5
        _ = counter.update(time: t, y: 0.5, torsoLength: torso)
        #expect(counter.isPaused(at: t))
        #expect(counter.rate(at: t) == nil)
        #expect(FeedbackPolicy().decide(at: t, counter: counter, armsStraight: true) == .keepGoing)
    }

    @Test(arguments: zip([80.0, 110, 140], [CPRFeedback.faster, .good, .slower]))
    func rateFeedback(bpm: Double, expected: CPRFeedback) {
        let counter = CompressionCounter()
        run(counter, compressions(bpm: bpm, seconds: 10))
        #expect(FeedbackPolicy().decide(at: 10, counter: counter, armsStraight: true) == expected)
    }

    @Test func bentArmsComeBeforeRate() {
        let counter = CompressionCounter()
        run(counter, compressions(bpm: 80, seconds: 10))
        #expect(FeedbackPolicy().decide(at: 10, counter: counter, armsStraight: false) == .straightenArms)
    }

    @Test func feedbackIsThrottled() {
        let counter = CompressionCounter()
        run(counter, compressions(bpm: 80, seconds: 10))
        let policy = FeedbackPolicy()
        #expect(policy.decide(at: 10, counter: counter, armsStraight: true) == .faster)
        #expect(policy.decide(at: 11, counter: counter, armsStraight: true) == nil)
    }

    @Test func armAngleMeasuresTheElbow() {
        #expect(abs(armAngle(shoulder: CGPoint(x: 0, y: 0), elbow: CGPoint(x: 0, y: 1), wrist: CGPoint(x: 0, y: 2)) - 180) < 0.001)
        #expect(abs(armAngle(shoulder: CGPoint(x: 0, y: 0), elbow: CGPoint(x: 0, y: 1), wrist: CGPoint(x: 1, y: 1)) - 90) < 0.001)
    }

    @Test func sessionSummary() {
        let counter = CompressionCounter()
        var stats = SessionStats()
        for (t, y) in compressions(bpm: 110, seconds: 20) {
            let update = counter.update(time: t, y: y, torsoLength: torso)
            stats.update(dt: 1 / fps, rate: update.rate, armsStraight: true)
        }
        let summary = stats.summary(count: counter.count)
        #expect(isClose(summary.averageRate.map(Double.init), 110))
        #expect(summary.timeInRangePercent >= 90)
        #expect(summary.straightArmsPercent == 100)
    }
}

@MainActor
@Suite("CPR coach view model")
struct CPRCoachViewModelTests {
    @Test func coachesASteadyRescuer() {
        let speech = SilentSpeech()
        let viewModel = CPRCoachViewModel(provider: MockBodyPoseProvider(), speech: speech)
        for i in 0..<Int(15 * fps) {
            let t = Double(i) / fps
            viewModel.handle(PoseFrame(time: t, joints: MockBodyPoseProvider.pose(at: t, rate: 110), imageSize: MockBodyPoseProvider.imageSize))
        }
        #expect(isClose(viewModel.rate, 110))
        #expect(viewModel.isRateInRange)
        #expect(viewModel.armsStraight == true)
        #expect(abs(viewModel.count - 27) <= 2)
        #expect(speech.spoken.contains(CPRFeedback.good.rawValue))
    }

    @Test func asksForFasterCompressions() {
        let speech = SilentSpeech()
        let viewModel = CPRCoachViewModel(provider: MockBodyPoseProvider(), speech: speech)
        for i in 0..<Int(10 * fps) {
            let t = Double(i) / fps
            viewModel.handle(PoseFrame(time: t, joints: MockBodyPoseProvider.pose(at: t, rate: 80), imageSize: MockBodyPoseProvider.imageSize))
        }
        #expect(speech.spoken.contains(CPRFeedback.faster.rawValue))
    }

    @Test func showsNoArmStateWithoutAPerson() {
        let viewModel = CPRCoachViewModel(provider: MockBodyPoseProvider(), speech: SilentSpeech())
        viewModel.handle(PoseFrame(time: 0, joints: nil, imageSize: MockBodyPoseProvider.imageSize))
        #expect(viewModel.armsStraight == nil)
        #expect(viewModel.count == 0)
    }
}
