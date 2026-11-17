import UIKit

// Vibracion al ritmo de la respiracion, para seguirla con los ojos cerrados
@MainActor
protocol BreathHaptics: AnyObject {
    func play(_ phase: BreathPhase, seconds: Double)
    func stop()
}

// Inhalar: toques que van subiendo de intensidad. Sostener: un toque firme. Exhalar: toques que se apagan
@MainActor
final class DeviceBreathHaptics: BreathHaptics {
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private var task: Task<Void, Never>?

    func play(_ phase: BreathPhase, seconds: Double) {
        stop()
        switch phase {
        case .hold:
            rigid.impactOccurred(intensity: 0.7)
        case .inhale, .exhale:
            let rising = phase == .inhale
            let interval = rising ? 0.4 : 0.8
            let taps = max(1, Int(seconds / interval))
            soft.prepare()
            task = Task { [soft] in
                for tap in 0..<taps {
                    guard !Task.isCancelled else { return }
                    let progress = Double(tap) / Double(max(taps - 1, 1))
                    soft.impactOccurred(intensity: 0.2 + 0.7 * (rising ? progress : 1 - progress))
                    try? await Task.sleep(for: .seconds(interval))
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

// Sin vibracion, para pruebas
@MainActor
final class SilentBreathHaptics: BreathHaptics {
    private(set) var played: [BreathPhase] = []

    func play(_ phase: BreathPhase, seconds: Double) {
        played.append(phase)
    }

    func stop() {}
}
