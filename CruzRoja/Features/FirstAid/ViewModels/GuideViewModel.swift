import Foundation
import Observation

@MainActor
@Observable
final class GuideViewModel {
    let guide: FirstAidGuide
    private(set) var stepIndex = 0
    private(set) var secondsLeft: Int?
    // Toggles on every compression beat so the view can pulse and vibrate
    private(set) var beat = false

    let ambulance: AmbulanceTracker
    private let speech: SpeechSynthesizing

    init(guide: FirstAidGuide, speech: SpeechSynthesizing, ambulance: AmbulanceTracker) {
        self.guide = guide
        self.speech = speech
        self.ambulance = ambulance
    }

    var step: GuideStep { guide.steps[stepIndex] }
    var isFirstStep: Bool { stepIndex == 0 }
    var isLastStep: Bool { stepIndex == guide.steps.count - 1 }

    var isMuted: Bool {
        get { speech.isMuted }
        set { speech.isMuted = newValue }
    }

    func start() {
        ambulance.request()
    }

    func stop() {
        speech.stop()
    }

    func next() {
        guard !isLastStep else { return }
        stepIndex += 1
    }

    func previous() {
        guard !isFirstStep else { return }
        stepIndex -= 1
    }

    func repeatInstruction() {
        speech.speak(step.instruction)
    }

    // Speaks the step and runs its timer; cancelled when the step changes
    func runStep() async {
        speech.speak("\(step.title). \(step.instruction)")
        secondsLeft = step.seconds
        while let left = secondsLeft, left > 0 {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            secondsLeft = left - 1
        }
        if secondsLeft == 0 { speech.speak("Tiempo cumplido.") }
    }

    func runBeat() async {
        guard let rate = step.rate else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60.0 / Double(rate)))
            beat.toggle()
        }
    }

    func announceArrivalIfNeeded() {
        if ambulance.hasArrived {
            speech.speak("La ambulancia llegó. Cuéntale a los paramédicos qué pasó y qué hiciste.")
        }
    }
}
