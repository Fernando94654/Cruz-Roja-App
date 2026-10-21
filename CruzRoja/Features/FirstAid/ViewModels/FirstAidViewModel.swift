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
    private let assistant: FirstAidAssisting

    let suggestions = [
        "Mi papá no respira y no responde",
        "Un niño se está atragantando",
        "Me corté y sangra mucho",
        "Se quemó con aceite",
    ]

    var guides: [FirstAidGuide] { FirstAidGuide.catalog }
    var hasDraft: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty }

    init(assistant: FirstAidAssisting, speech: SpeechSynthesizing, ambulance: AmbulanceTracker, messages: [ChatMessage] = []) {
        self.assistant = assistant
        self.speech = speech
        self.ambulance = ambulance
        self.messages = messages
    }

    func start() {
        ambulance.request()
    }

    func stop() {
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
        speech.speak(answer.text)
    }

    // Fixed phrase until on-device speech recognition exists
    func dictate() async {
        speech.stop()
        isListening = true
        try? await Task.sleep(for: .seconds(2))
        isListening = false
        await send("Mi abuela se desmayó y está mareada")
    }

    func toggleSpeech(for answer: AssistantAnswer) {
        if speech.isSpeaking { speech.stop() } else { speech.speak(answer.text) }
    }
}
