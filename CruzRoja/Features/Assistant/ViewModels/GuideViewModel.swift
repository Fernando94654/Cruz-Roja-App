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

    let lessons: LearnViewModel
    private let speech: SpeechSynthesizing
    private var isActive = true

    // Owns its own lesson list so the related video loads independently
    init(guide: FirstAidGuide, speech: SpeechSynthesizing, lessonsService: LessonsServicing) {
        self.guide = guide
        self.speech = speech
        lessons = LearnViewModel(service: lessonsService)
    }

    var step: GuideStep { guide.steps[stepIndex] }
    var isFirstStep: Bool { stepIndex == 0 }
    var isLastStep: Bool { stepIndex == guide.steps.count - 1 }

    var isMuted: Bool {
        get { speech.isMuted }
        set { speech.isMuted = newValue }
    }

    // Called when the guide opens: steps may speak again
    func start() {
        isActive = true
    }

    // Called when leaving: silences speech and stops timers
    func stop() {
        isActive = false
        speech.stop()
    }

    // Moves to the next step
    func next() {
        guard !isLastStep else { return }
        stepIndex += 1
    }

    // Moves to the previous step
    func previous() {
        guard !isFirstStep else { return }
        stepIndex -= 1
    }

    // Reads the current instruction again
    func repeatInstruction() {
        speech.speak(step.instruction)
    }

    // Speaks the step and runs its timer; cancelled when the step changes
    func runStep() async {
        guard isActive, !Task.isCancelled else { return }
        speech.speak("\(step.title). \(step.instruction)")
        secondsLeft = step.seconds
        while let left = secondsLeft, left > 0 {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled || !isActive { return }
            secondsLeft = left - 1
        }
        if secondsLeft == 0 { speech.speak("Tiempo cumplido.") }
    }

    // Ticks at the step's compression rate until the step changes
    func runBeat() async {
        guard let rate = step.rate else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60.0 / Double(rate)))
            guard !Task.isCancelled, isActive else { return }
            beat.toggle()
        }
    }
}
