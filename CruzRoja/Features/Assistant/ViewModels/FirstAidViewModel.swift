import Foundation
import Observation

@MainActor
@Observable
final class FirstAidViewModel {
    var draft = ""
    private(set) var messages: [ChatMessage]
    private(set) var isThinking = false
    private(set) var isListening = false

    let speech: SpeechSynthesizing
    let lessons: LearnViewModel
    private let assistant: FirstAidAssisting
    private var isActive = true

    let suggestions = [
        "Mi papá no respira y no responde",
        "Un niño se está atragantando",
        "Me corté y sangra mucho",
        "Se quemó con aceite",
    ]

    let guides: [FirstAidGuide]
    var hasDraft: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty }

    // Owns its own lesson list so related videos load independently
    init(assistant: FirstAidAssisting, speech: SpeechSynthesizing, lessonsService: LessonsServicing,
         guides: [FirstAidGuide] = FirstAidGuide.bundled, messages: [ChatMessage] = []) {
        self.assistant = assistant
        self.guides = guides
        self.speech = speech
        self.messages = messages
        lessons = LearnViewModel(service: lessonsService, guides: guides)
    }

    // Called when the screen opens: answers may speak again
    func start() {
        isActive = true
    }

    // Called when leaving: silences speech and blocks late answers
    func stop() {
        isActive = false
        speech.stop()
    }

    // Clears the conversation for a new emergency
    func reset() {
        speech.stop()
        messages.removeAll()
    }

    // Adds the question, asks the assistant and reads the answer aloud
    func send(_ text: String) async {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }
        draft = ""
        messages.append(.user(UUID(), question))
        isThinking = true
        let answer = await assistant.answer(question)
        isThinking = false
        messages.append(.assistant(answer))
        if isActive { speech.speak(answer.text) }
    }

    // Fixed phrase until on-device speech recognition exists
    func dictate() async {
        speech.stop()
        isListening = true
        try? await Task.sleep(for: .seconds(2))
        isListening = false
        guard isActive, !Task.isCancelled else { return }
        await send("Mi abuela se desmayó y está mareada")
    }

    // Reads an answer aloud again, or stops reading
    func toggleSpeech(for answer: AssistantAnswer) {
        if speech.isSpeaking { speech.stop() } else { speech.speak(answer.text) }
    }
}
