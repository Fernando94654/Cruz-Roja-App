import Foundation
import Observation

@MainActor
@Observable
final class FirstAidViewModel {
    var draft = ""
    private(set) var messages: [ChatMessage]
    private(set) var isThinking = false
    private(set) var isPreparingDictation = false
    private(set) var dictationError: String?
    var isListening: Bool { dictation.isListening }

    let speech: SpeechSynthesizing
    let lessons: LearnViewModel
    private let assistant: FirstAidAssisting
    private let dictation: Dictating
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
    init(assistant: FirstAidAssisting, speech: SpeechSynthesizing, dictation: Dictating, lessonsService: LessonsServicing,
         guides: [FirstAidGuide] = FirstAidGuide.bundled, messages: [ChatMessage] = []) {
        self.assistant = assistant
        self.dictation = dictation
        self.guides = guides
        self.speech = speech
        self.messages = messages
        lessons = LearnViewModel(service: lessonsService, guides: guides)
    }

    // Called when the screen opens: answers may speak again
    func start() {
        isActive = true
    }

    // Called when leaving: silences speech, closes the microphone and blocks late answers
    func stop() {
        isActive = false
        speech.stop()
        dictation.stop()
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

    // First tap listens and writes what the user says into the draft; second tap stops and sends it
    func toggleDictation() async {
        if dictation.isListening {
            dictation.stop()
            await send(draft)
            return
        }
        guard !isPreparingDictation else { return }
        speech.stop() // the assistant's voice would be transcribed too
        dictationError = nil
        draft = ""
        isPreparingDictation = true
        defer { isPreparingDictation = false }
        do {
            try await dictation.start(onText: { [weak self] text in
                self?.draft = text
            }, onError: { [weak self] message in
                self?.dictationError = message
            })
        } catch is CancellationError {
            return
        } catch {
            dictationError = error.localizedDescription
        }
    }

    // Reads an answer aloud again, or stops reading
    func toggleSpeech(for answer: AssistantAnswer) {
        if speech.isSpeaking { speech.stop() } else { speech.speak(answer.text) }
    }
}
