import Foundation
import Observation

@MainActor
@Observable
final class LessonViewModel {
    let lesson: Lesson

    private let speech: SpeechSynthesizing

    init(lesson: Lesson, speech: SpeechSynthesizing) {
        self.lesson = lesson
        self.speech = speech
    }

    var isSpeaking: Bool { speech.isSpeaking }

    func toggleSpeech() {
        if speech.isSpeaking {
            speech.stop()
        } else {
            speech.speak(([lesson.title] + lesson.steps).joined(separator: ". "))
        }
    }

    func stop() {
        speech.stop()
    }
}
