import Foundation
import Observation

// Controla "Dictar mis datos": el micrófono, el texto dictado y el llenado con IA
@MainActor
@Observable
final class ProfileDictationViewModel {
    // Lo que dijo la persona; también se puede corregir a mano antes de llenar
    var transcript = ""
    private(set) var isPreparing = false
    private(set) var isFilling = false
    // Lo que se agregó al perfil, para que la persona lo revise antes de guardar
    private(set) var added: [String] = []
    // Aviso cuando la fecha de nacimiento es aproximada o no coincide con la edad dicha
    private(set) var ageNote: String?
    private(set) var message: String?
    var errorMessage: String?

    let dictation: Dictating
    private let extractor: ProfileExtracting

    init(dictation: Dictating, extractor: ProfileExtracting) {
        self.dictation = dictation
        self.extractor = extractor
    }

    var isListening: Bool { dictation.isListening }

    var canFill: Bool {
        !isListening && !isFilling && !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Empieza a escuchar; el texto aparece mientras la persona habla
    func start() async {
        guard !isListening, !isPreparing else { return }
        transcript = ""
        added = []
        ageNote = nil
        message = nil
        errorMessage = nil
        isPreparing = true
        defer { isPreparing = false }
        do {
            try await dictation.start(onText: { [weak self] text in
                self?.transcript = text
            }, onError: { [weak self] message in
                self?.errorMessage = message
            })
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        if isListening { dictation.stop() }
    }

    // Acomoda lo dictado en el perfil sin borrar lo que ya tenía; la persona revisa y guarda
    func fill(_ profile: MedicalProfile) async -> MedicalProfile {
        stop()
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return profile }
        isFilling = true
        defer { isFilling = false }
        do {
            let fields = try await extractor.extract(text)
            let result = profile.merging(fields)
            added = result.added
            ageNote = result.ageNote
            message = Self.message(for: fields, addedSomething: !result.added.isEmpty)
            return result.profile
        } catch {
            message = "No se pudieron acomodar los datos. Llena los campos a mano."
            return profile
        }
    }

    private static func message(for fields: ProfileFields, addedSomething: Bool) -> String {
        if fields.isEmpty { return "No reconocí datos médicos. Intenta de nuevo o llena los campos a mano." }
        if !addedSomething { return "Esos datos ya estaban en tu perfil." }
        switch fields.source {
        case .ai: return "Llenado con IA en tu iPhone. Revisa que esté correcto antes de guardar."
        case .rules(let reason?): return "IA no disponible (\(reason)). Se llenó con palabras clave; revisa antes de guardar."
        case .rules(nil): return "Se llenó con palabras clave. Revisa antes de guardar."
        }
    }
}
