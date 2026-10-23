import Foundation
import Observation

@MainActor
protocol Dictating: AnyObject {
    var isListening: Bool { get }
    // Streams partial transcriptions until stop() is called
    func start(onText: @escaping @MainActor (String) -> Void) async throws
    func stop()
}

enum DictationError: LocalizedError {
    case notAuthorized
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Permite el micrófono y el reconocimiento de voz en Ajustes para dictar."
        case .unavailable: "El dictado no está disponible en este momento. Escribe lo que pasa."
        }
    }
}

// No-op dictation for previews and tests
@MainActor
@Observable
final class SilentDictation: Dictating {
    private(set) var isListening = false
    var transcript = ""

    func start(onText: @escaping @MainActor (String) -> Void) async throws {
        isListening = true
        onText(transcript)
    }

    func stop() {
        isListening = false
    }
}
