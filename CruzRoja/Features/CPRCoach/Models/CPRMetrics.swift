import Foundation

/// Every threshold used by the CPR coach, in one place.
struct CPRConfig: Sendable {
    // Smallest movement that can count as a compression, in torso lengths
    var minAmplitude = 0.02
    // Counting threshold as a fraction of the up-and-down swings of the last seconds
    var amplitudeFraction = 0.35
    var swingWindow: TimeInterval = 4
    // Exponential smoothing of the signal (1 = no smoothing)
    var smoothing = 0.5
    // Slow body drift removed with a moving average of this length
    var detrendWindow: TimeInterval = 1
    // Torso length is the median over this window, not the noisy per-frame value
    var torsoWindow: TimeInterval = 2
    // Rate comes from the rhythm (autocorrelation) of the last seconds
    var rateWindow: TimeInterval = 5
    var minPeriodicity = 0.3
    // A shorter lag this strong relative to the best one is the real period, not a harmonic
    var harmonicFraction = 0.4
    // A peak this close to the current period, and at least this periodic, keeps the current rhythm
    var continuityTolerance = 0.2
    var continuityPeriodicity = 0.15
    var minRate = 50.0
    var maxRate = 180.0
    // A compression closer than this fraction of the current period is a double count
    var refractoryFraction = 0.5
    // The body counts as moving when the last second swings more than minAmplitude
    var motionWindow: TimeInterval = 1
    var minInterval: TimeInterval = 0.3
    var targetMinRate = 100.0
    var targetMaxRate = 120.0
    var straightArmDegrees = 160.0
    var pauseAfter: TimeInterval = 3
    var speakEvery: TimeInterval = 4
    var praiseEvery: TimeInterval = 8
}

/// Counter state after one frame.
struct CounterUpdate: Equatable, Sendable {
    let count: Int
    let rate: Double?
    let compressed: Bool
}

private struct Sample {
    let time: TimeInterval
    let value: Double
}

/// Counts compressions from the vertical shoulder position and measures their rhythm.
final class CompressionCounter {
    static let resampleHz = 30.0

    let config: CPRConfig
    private(set) var count = 0
    private(set) var lastCompressionTime: TimeInterval?
    private var raw: [Sample] = []
    private var torsos: [Sample] = []
    private var signal: [Sample] = []
    private var swings: [Sample] = []
    private var smoothed: Double?
    private var goingDown = true
    private var extreme = 0.0
    private var extremeTime: TimeInterval = 0
    private var lastTurn: Double?
    private var currentRate: Double?
    private var phase = 0.0
    private var lastTime: TimeInterval?

    init(config: CPRConfig = CPRConfig()) {
        self.config = config
    }

    /// Feeds one frame; y is the shoulder height and grows downward as in image coordinates.
    func update(time t: TimeInterval, y: Double, torsoLength: Double) -> CounterUpdate {
        let c = config
        push(&torsos, t, torsoLength, keep: c.torsoWindow)
        let torso = median(torsos.map(\.value))

        push(&raw, t, y / torso, keep: c.detrendWindow)
        let baseline = raw.map(\.value).reduce(0, +) / Double(raw.count)
        let x = y / torso - baseline
        let first = smoothed == nil
        let s = first ? x : c.smoothing * x + (1 - c.smoothing) * smoothed!
        smoothed = s
        push(&signal, t, s, keep: c.rateWindow)

        if first {
            extreme = s
            extremeTime = t
        }
        let peakTime = trackPeaks(s, t)
        let dt = lastTime.map { t - $0 } ?? 0
        lastTime = t

        currentRate = count >= 2 ? rhythmRate(at: t) : nil
        var compressed = false
        if let rate = currentRate, isMoving(at: t) {
            // Once the rhythm is clear, count by its phase so one missed or extra peak can't change the total
            phase += rate / 60 * dt
            if phase >= 1 {
                phase -= 1
                compressed = register(at: t)
            }
        } else if let peakTime {
            compressed = register(at: peakTime)
            phase = 0
        }
        return CounterUpdate(count: count, rate: rate(at: t), compressed: compressed)
    }

    /// Compressions per minute, or nil while paused or before the rhythm is clear.
    func rate(at t: TimeInterval) -> Double? {
        isPaused(at: t) ? nil : currentRate
    }

    /// True when compressions started and then stopped for longer than the pause limit.
    func isPaused(at t: TimeInterval) -> Bool {
        guard let last = lastCompressionTime else { return false }
        return t - last > config.pauseAfter
    }

    // Hysteresis peak detection; returns the time of a bottom that was just confirmed
    private func trackPeaks(_ s: Double, _ t: TimeInterval) -> TimeInterval? {
        let threshold = threshold(at: t)
        if goingDown {
            if s >= extreme {
                extreme = s
                extremeTime = t
            } else if s <= extreme - threshold {
                let bottom = extremeTime
                turn(s, t, goingDown: false)
                return bottom
            }
        } else {
            if s <= extreme {
                extreme = s
                extremeTime = t
            } else if s >= extreme + threshold {
                turn(s, t, goingDown: true)
            }
        }
        return nil
    }

    // Records the swing that just ended and starts tracking the opposite direction
    private func turn(_ s: Double, _ t: TimeInterval, goingDown: Bool) {
        if let lastTurn {
            push(&swings, t, abs(extreme - lastTurn), keep: config.swingWindow)
        }
        lastTurn = extreme
        self.goingDown = goingDown
        extreme = s
        extremeTime = t
    }

    // Hysteresis that follows how much the person is moving now; old swings, like getting into position, expire
    private func threshold(at t: TimeInterval) -> Double {
        let recent = swings.filter { t - $0.time <= config.swingWindow }.map(\.value)
        guard recent.count >= 3 else { return config.minAmplitude }
        return max(config.minAmplitude, config.amplitudeFraction * median(recent))
    }

    // True while the last second still shows compression-sized movement
    private func isMoving(at t: TimeInterval) -> Bool {
        let recent = signal.filter { t - $0.time <= config.motionWindow }.map(\.value)
        guard recent.count >= 5, let lo = recent.min(), let hi = recent.max() else { return false }
        return hi - lo >= config.minAmplitude
    }

    // Counts a compression unless it comes too soon after the previous one
    private func register(at time: TimeInterval) -> Bool {
        if let last = lastCompressionTime {
            var refractory = config.minInterval
            if let currentRate {
                refractory = max(refractory, config.refractoryFraction * 60 / currentRate)
            }
            if time - last < refractory { return false }
        }
        count += 1
        lastCompressionTime = time
        return true
    }

    // Compressions per minute from the autocorrelation of the last seconds, or nil if not periodic
    private func rhythmRate(at t: TimeInterval) -> Double? {
        let c = config
        let hz = Self.resampleHz
        let window = signal.filter { t - $0.time <= c.rateWindow }
        guard window.count >= 20, let start = window.first?.time, let end = window.last?.time,
              end - start >= c.rateWindow / 2 else { return nil }

        var heights: [Double] = []
        var g = start
        while g < end {
            heights.append(interpolate(g, xs: window.map(\.time), ys: window.map(\.value)))
            g += 1 / hz
        }
        // Autocorrelation of the speed, not the height, so slow drift can't hide the rhythm
        var v = movingAverage3(zip(heights.dropFirst(), heights).map { $0 - $1 })
        let mean = v.reduce(0, +) / Double(max(v.count, 1))
        v = v.map { $0 - mean }
        let n = v.count
        let energy = v.reduce(0) { $0 + $1 * $1 }
        guard energy > 0 else { return nil }

        let lo = max(1, Int(hz * 60 / c.maxRate))
        let hi = min(n - 2, Int(hz * 60 / c.minRate))
        guard hi > lo else { return nil }
        let lags = Array(lo...hi)
        // Normalized per lag so longer lags are not penalized for having fewer samples
        let ac = lags.map { k -> Double in
            var sum = 0.0
            for i in 0..<(n - k) { sum += v[i] * v[i + k] }
            return sum / Double(n - k) / (energy / Double(n))
        }

        // Only true local maxima count; the edges of the range are not a rhythm
        let peaks = (1..<(ac.count - 1)).filter { ac[$0] > ac[$0 - 1] && ac[$0] >= ac[$0 + 1] && ac[$0] > 0 }
        guard let best = peaks.map({ ac[$0] }).max(), best >= c.minPeriodicity else { return nil }
        // The shortest clear lag avoids picking a multiple of the period
        var k = peaks.first { ac[$0] >= c.harmonicFraction * best }!
        // Keep following the current rhythm while it is still visible, so the needle doesn't flicker
        if let currentRate {
            let previous = hz * 60 / currentRate
            let near = peaks.filter { abs(Double(lags[$0]) - previous) <= c.continuityTolerance * previous && ac[$0] >= c.continuityPeriodicity }
            if let strongest = near.max(by: { ac[$0] < ac[$1] }) { k = strongest }
        }

        let (a, b, d) = (ac[k - 1], ac[k], ac[k + 1])
        let denom = a - 2 * b + d
        var lag = Double(lags[k]) + (denom != 0 ? 0.5 * (a - d) / denom : 0)
        // At the real period, half a lag is out of phase; if it still correlates, the lag is a double period
        if lag / 2 >= Double(lags[0]), interpolate(lag / 2, xs: lags.map(Double.init), ys: ac) >= c.harmonicFraction * b {
            lag /= 2
        }
        return 60 * hz / lag
    }
}

/// Elbow angle in degrees; 180 means a fully straight arm.
func armAngle(shoulder: CGPoint, elbow: CGPoint, wrist: CGPoint) -> Double {
    let v1 = (x: Double(shoulder.x - elbow.x), y: Double(shoulder.y - elbow.y))
    let v2 = (x: Double(wrist.x - elbow.x), y: Double(wrist.y - elbow.y))
    let norm = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
    guard norm > 0 else { return 180 }
    let cos = (v1.x * v2.x + v1.y * v2.y) / norm
    return acos(min(1, max(-1, cos))) * 180 / .pi
}

/// Spoken corrections, in priority order.
enum CPRFeedback: String, Sendable {
    case keepGoing = "Continúa las compresiones"
    case straightenArms = "Estira los brazos"
    case faster = "Más rápido"
    case slower = "Más lento"
    case good = "Bien, sigue así"
}

/// Picks the correction to speak, at most one every few seconds.
final class FeedbackPolicy {
    let config: CPRConfig
    private var lastSpoken: TimeInterval?
    private var lastPraise: TimeInterval?

    init(config: CPRConfig = CPRConfig()) {
        self.config = config
    }

    /// Message to speak now, or nil.
    func decide(at t: TimeInterval, counter: CompressionCounter, armsStraight: Bool?) -> CPRFeedback? {
        guard counter.count > 0 else { return nil }
        if let lastSpoken, t - lastSpoken < config.speakEvery { return nil }
        guard let message = current(at: t, counter: counter, armsStraight: armsStraight) else { return nil }
        if message == .good {
            if let lastPraise, t - lastPraise < config.praiseEvery { return nil }
            lastPraise = t
        }
        lastSpoken = t
        return message
    }

    /// Highest-priority message for the current state, without throttling.
    func current(at t: TimeInterval, counter: CompressionCounter, armsStraight: Bool?) -> CPRFeedback? {
        if counter.isPaused(at: t) { return .keepGoing }
        if armsStraight == false { return .straightenArms }
        guard let rate = counter.rate(at: t) else { return nil }
        if rate < config.targetMinRate { return .faster }
        if rate > config.targetMaxRate { return .slower }
        return .good
    }
}

/// End-of-session totals, ready to attach to the emergency report.
struct CPRSessionSummary: Equatable, Sendable {
    let compressions: Int
    let duration: TimeInterval
    let averageRate: Int?
    let timeInRangePercent: Int
    let straightArmsPercent: Int
}

/// Accumulates time in range and arm posture for the summary.
struct SessionStats {
    let config: CPRConfig
    private(set) var duration: TimeInterval = 0
    private var active: TimeInterval = 0
    private var inRange: TimeInterval = 0
    private var straight: TimeInterval = 0
    private var rates: [Double] = []

    init(config: CPRConfig = CPRConfig()) {
        self.config = config
    }

    /// Adds one frame of duration dt.
    mutating func update(dt: TimeInterval, rate: Double?, armsStraight: Bool?) {
        duration += dt
        guard let rate else { return }
        active += dt
        rates.append(rate)
        if (config.targetMinRate...config.targetMaxRate).contains(rate) { inRange += dt }
        if armsStraight == true { straight += dt }
    }

    /// Totals for the session.
    func summary(count: Int) -> CPRSessionSummary {
        let percent = { (part: TimeInterval) in active > 0 ? Int((100 * part / active).rounded()) : 0 }
        return CPRSessionSummary(
            compressions: count,
            duration: duration,
            averageRate: rates.isEmpty ? nil : Int((rates.reduce(0, +) / Double(rates.count)).rounded()),
            timeInRangePercent: percent(inRange),
            straightArmsPercent: percent(straight)
        )
    }
}

// MARK: - Helpers

private func push(_ buffer: inout [Sample], _ t: TimeInterval, _ value: Double, keep: TimeInterval) {
    buffer.append(Sample(time: t, value: value))
    while let first = buffer.first, t - first.time > keep { buffer.removeFirst() }
}

private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let mid = sorted.count / 2
    return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
}

// Linear interpolation like numpy.interp: clamps outside the range
private func interpolate(_ x: Double, xs: [Double], ys: [Double]) -> Double {
    guard let first = xs.first, let last = xs.last else { return 0 }
    if x <= first { return ys[0] }
    if x >= last { return ys[ys.count - 1] }
    var lo = 0
    var hi = xs.count - 1
    while hi - lo > 1 {
        let mid = (lo + hi) / 2
        if xs[mid] <= x { lo = mid } else { hi = mid }
    }
    let span = xs[hi] - xs[lo]
    return span == 0 ? ys[lo] : ys[lo] + (ys[hi] - ys[lo]) * (x - xs[lo]) / span
}

// 3-point moving average with zero padding, like numpy.convolve(mode="same")
private func movingAverage3(_ x: [Double]) -> [Double] {
    x.indices.map { i in
        let prev = i > 0 ? x[i - 1] : 0
        let next = i < x.count - 1 ? x[i + 1] : 0
        return (prev + x[i] + next) / 3
    }
}
