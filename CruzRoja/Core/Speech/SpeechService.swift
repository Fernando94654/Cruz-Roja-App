import AVFoundation

@MainActor
@Observable
final class Voz: NSObject, AVSpeechSynthesizerDelegate {
    static let compartida = Voz()

    private(set) var hablando = false
    var silenciada = false {
        didSet { if silenciada { callar() } }
    }

    @ObservationIgnored private let sintetizador = AVSpeechSynthesizer()
    @ObservationIgnored nonisolated(unsafe) private var voz: AVSpeechSynthesisVoice?

    private override init() {
        super.init()
        sintetizador.delegate = self
        // buscar la voz bloquea el hilo principal, por eso se hace aparte
        Task.detached(priority: .userInitiated) {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            self.voz = AVSpeechSynthesisVoice(language: "es-MX") ?? AVSpeechSynthesisVoice(language: "es-ES")
        }
    }

    func decir(_ texto: String) {
        guard !silenciada else { return }
        callar()
        try? AVAudioSession.sharedInstance().setActive(true)
        let frase = AVSpeechUtterance(string: texto)
        frase.voice = voz
        sintetizador.speak(frase)
    }

    func callar() {
        if sintetizador.isSpeaking {
            sintetizador.stopSpeaking(at: .immediate)
        }
        hablando = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.hablando = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.hablando = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.hablando = false }
    }
}
