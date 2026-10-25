import Foundation
import Observation

@MainActor
@Observable
final class LessonViewModel {
    let lesson: Lesson
    let progress: LessonProgress?

    private let speech: SpeechSynthesizing

    // Progress is optional so lessons opened from an emergency skip the completion button
    init(lesson: Lesson, speech: SpeechSynthesizing, progress: LessonProgress? = nil) {
        self.lesson = lesson
        self.speech = speech
        self.progress = progress
    }

    var isCompleted: Bool { progress?.isCompleted(lesson) ?? false }

    // Marks or unmarks this lesson as completed
    func toggleCompletion() async {
        await progress?.toggle(lesson)
    }

    var isSpeaking: Bool { speech.isSpeaking }

    // Reads the title and steps aloud, or stops reading
    func toggleSpeech() {
        if speech.isSpeaking {
            speech.stop()
        } else {
            speech.speak(([lesson.title] + lesson.steps).joined(separator: ". "))
        }
    }

    // Stops reading aloud
    func stop() {
        speech.stop()
    }
}
