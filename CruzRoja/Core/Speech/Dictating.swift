import Foundation
import Observation

@MainActor
protocol Dictating: AnyObject {
    var isListening: Bool { get }
    // Streams partial transcriptions until stop() is called
    func start(onText: @escaping @MainActor (String) -> Void,
               onError: @escaping @MainActor (String) -> Void) async throws
    func stop()
}

enum DictationError: LocalizedError {
    case notAuthorized
    case speechPermissionTimedOut
    case microphonePermissionTimedOut
    case alreadyListening
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Permite el micrófono y el reconocimiento de voz en Ajustes para dictar."
        case .speechPermissionTimedOut: "No respondió el permiso de reconocimiento de voz. Abre la app en el simulador o en tu iPhone para concederlo y vuelve a intentar."
        case .microphonePermissionTimedOut: "No respondió el permiso del micrófono. Abre la app en el simulador o en tu iPhone para concederlo y vuelve a intentar."
        case .alreadyListening: "El micrófono ya está en uso. Detén el dictado anterior e inténtalo de nuevo."
        case .unavailable: "El dictado no está disponible en este momento. Escribe lo que pasa."
        }
    }
}

// No-op dictation for tests
@MainActor
@Observable
final class SilentDictation: Dictating {
    private(set) var isListening = false
    var transcript = ""

    func start(onText: @escaping @MainActor (String) -> Void,
               onError: @escaping @MainActor (String) -> Void) async throws {
        isListening = true
        onText(transcript)
    }

    func stop() {
        isListening = false
    }
}
