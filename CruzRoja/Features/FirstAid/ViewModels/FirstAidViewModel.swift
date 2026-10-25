import Foundation
import Observation

@MainActor
@Observable
final class FirstAidViewModel {
    var draft = ""
    private(set) var messages: [ChatMessage]
    private(set) var isThinking = false
    private(set) var isListening = false

    let ambulance: AmbulanceTracker
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

    init(assistant: FirstAidAssisting, speech: SpeechSynthesizing, ambulance: AmbulanceTracker, lessonsService: LessonsServicing,
         guides: [FirstAidGuide] = FirstAidGuide.bundled, messages: [ChatMessage] = []) {
        self.assistant = assistant
        self.guides = guides
        self.speech = speech
        self.ambulance = ambulance
        self.messages = messages
        lessons = LearnViewModel(service: lessonsService, guides: guides)
    }

    func start() {
        isActive = true
        ambulance.request()
    }

    func stop() {
        isActive = false
        speech.stop()
    }

    func reset() {
        speech.stop()
        messages.removeAll()
    }

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

    func toggleSpeech(for answer: AssistantAnswer) {
        if speech.isSpeaking { speech.stop() } else { speech.speak(answer.text) }
    }
}
