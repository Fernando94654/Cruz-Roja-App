import AVFoundation

@MainActor
@Observable
final class SpeechService: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false
    var isMuted = false {
        didSet { if isMuted { stop() } }
    }

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored nonisolated(unsafe) private var voice: AVSpeechSynthesisVoice?

    override init() {
        super.init()
        synthesizer.delegate = self
        // Looking up the voice blocks the main thread, so it runs detached
        Task.detached(priority: .userInitiated) {
            self.voice = AVSpeechSynthesisVoice(language: "es-MX") ?? AVSpeechSynthesisVoice(language: "es-ES")
        }
    }

    func speak(_ text: String) {
        guard !isMuted else { return }
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
