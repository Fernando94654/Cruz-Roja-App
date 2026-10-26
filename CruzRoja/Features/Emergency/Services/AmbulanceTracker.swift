import Foundation
import Observation

// Simulated ambulance: the countdown runs 4x faster for demos
@MainActor
@Observable
final class AmbulanceTracker {
    let unit = "Ambulancia 214"
    private(set) var secondsLeft = 0
    private(set) var totalSeconds = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    var isOnTheWay: Bool { task != nil }
    var hasArrived: Bool { isOnTheWay && secondsLeft == 0 }
    var progress: Double { totalSeconds > 0 ? 1 - Double(secondsLeft) / Double(totalSeconds) : 0 }
    var timeLeft: String { String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60) }

    var status: String {
        if hasArrived { return "La ambulancia llegó" }
        return switch secondsLeft {
        case 1..<60: "Llegando"
        default: "En camino"
        }
    }

    /// Starts the simulated ambulance countdown.
    func request(seconds: Int = 480) {
        guard !isOnTheWay else { return }
        totalSeconds = seconds
        secondsLeft = seconds
        task = Task {
            while secondsLeft > 0 {
                try? await Task.sleep(for: .seconds(0.25))
                if Task.isCancelled { return }
                secondsLeft -= 1
            }
        }
    }
}
