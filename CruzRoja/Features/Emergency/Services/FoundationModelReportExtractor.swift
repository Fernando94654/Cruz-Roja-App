#if canImport(FoundationModels)
import FoundationModels

// Structured answer the on-device model must produce; empty strings mean "not mentioned"
@available(iOS 26.0, *)
@Generable
struct ReportDraft {
    @Guide(description: "Para quién es la emergencia: 'yo' si le pasa a quien escribe, 'familiar' si es un familiar, 'otra persona' si es alguien más.", .anyOf(["yo", "familiar", "otra persona"]))
    var forWhom: String

    @Guide(description: "Cómo se refiere a la persona afectada, en una o dos palabras con mayúscula inicial (por ejemplo 'Abuela', 'Papá', 'Señor'). Vacío si es quien escribe o no se sabe.")
    var patientName: String

    @Guide(description: "Motivo principal de la emergencia en pocas palabras (por ejemplo 'Caída', 'Dolor abdominal', 'Accidente vial'). Vacío si no se entiende.")
    var reason: String

    @Guide(description: "Número de personas lesionadas o afectadas. 1 si no se menciona.", .range(1...20))
    var injuredCount: Int

    @Guide(description: "Lesión o síntoma principal en pocas palabras (por ejemplo 'Golpe en la cabeza', 'Vómito'). Vacío si no se menciona.")
    var injury: String

    @Guide(description: "Tipo de lugar: 'Casa habitación', 'Vía pública', 'Trabajo', 'Escuela', 'Parque' u otro en pocas palabras. Vacío si no se menciona.")
    var place: String

    @Guide(description: "Referencias para encontrar el lugar (piso, puerta, color de la casa, entre qué calles). Vacío si no se mencionan.")
    var reference: String

    @Guide(description: "Estado mental de la persona afectada. Vacío si no se menciona.", .anyOf(["", "Alerta", "Confundido", "Inconsciente"]))
    var mentalState: String

    @Guide(description: "Cómo respira la persona afectada. Vacío si no se menciona.", .anyOf(["", "Normal", "Con dificultad", "No respira"]))
    var breathing: String

    @Guide(description: "Color de la piel de la persona afectada. Vacío si no se menciona.", .anyOf(["", "Normal", "Pálida", "Azulada"]))
    var skin: String

    @Guide(description: "Resumen para el operador de Cruz Roja en una o dos oraciones en español, solo con lo que se dijo.")
    var summary: String
}

// Fills the report with Apple's on-device language model
@available(iOS 26.0, *)
@MainActor
final class FoundationModelReportExtractor: ReportExtracting {
    private static let instructions = """
        Eres un asistente de despacho de la Cruz Roja Mexicana. Recibes la descripción de una emergencia \
        escrita o dictada por una persona, a veces con errores o sin acentos. Extrae los datos del reporte \
        usando solo lo que la persona dijo. No inventes ni supongas datos; deja vacío lo que no se mencione. \
        Responde siempre en español.
        """

    // A fresh session per report keeps earlier reports out of the context
    private var nextSession: LanguageModelSession?

    func prewarm() {
        session().prewarm()
    }

    func extract(_ text: String) async throws -> ExtractedFields {
        let current = session()
        nextSession = nil
        let draft = try await current.respond(to: "Descripción de la emergencia: \(text)", generating: ReportDraft.self).content
        return ExtractedFields(
            reportingFor: Self.reportingFor(draft.forWhom),
            patientName: Self.nonEmpty(draft.patientName),
            reason: Self.nonEmpty(draft.reason),
            injuredCount: draft.injuredCount,
            injury: Self.nonEmpty(draft.injury),
            place: Self.nonEmpty(draft.place),
            reference: Self.nonEmpty(draft.reference),
            mentalState: Self.nonEmpty(draft.mentalState),
            breathing: Self.nonEmpty(draft.breathing),
            skin: Self.nonEmpty(draft.skin),
            summary: Self.nonEmpty(draft.summary),
            source: .ai
        )
    }

    private func session() -> LanguageModelSession {
        if let nextSession { return nextSession }
        let session = LanguageModelSession(instructions: Self.instructions)
        nextSession = session
        return session
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // "yo" keeps whatever the user picked in the form
    private static func reportingFor(_ value: String) -> ReportingFor? {
        switch value {
        case "familiar": .familyMember
        case "otra persona": .someoneElse
        default: nil
        }
    }
}
#endif
