import Foundation
import Observation

@MainActor
@Observable
final class LessonViewModel {
    let lesson: Lesson
    let progress: LessonProgress?

    private let speech: SpeechSynthesizing

    init(lesson: Lesson, speech: SpeechSynthesizing, progress: LessonProgress? = nil) {
        self.lesson = lesson
        self.speech = speech
        self.progress = progress
    }

    var isCompleted: Bool { progress?.isCompleted(lesson) ?? false }

    func toggleCompletion() async {
        await progress?.toggle(lesson)
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
