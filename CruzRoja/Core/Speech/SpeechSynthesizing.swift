import Foundation
import Observation

@MainActor
protocol SpeechSynthesizing: AnyObject {
    var isSpeaking: Bool { get }
    var isMuted: Bool { get set }
    func speak(_ text: String)
    func stop()
}

// No-op speech for tests
@MainActor
@Observable
final class SilentSpeech: SpeechSynthesizing {
    private(set) var isSpeaking = false
    var isMuted = false
    private(set) var spoken: [String] = []

    func speak(_ text: String) {
        guard !isMuted else { return }
        spoken.append(text)
    }

    func stop() {
        isSpeaking = false
    }
}
