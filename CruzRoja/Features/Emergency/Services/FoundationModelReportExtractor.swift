#if canImport(FoundationModels)
import Foundation
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

    /// Loads the model so the first answer is faster.
    func prewarm() {
        session().prewarm()
    }

    /// Asks the model for a ReportDraft and maps it to report fields.
    func extract(_ text: String) async throws -> ExtractedFields {
        let current = session()
        nextSession = nil
        Log.ai.info("Prompt (\(text.count) chars): \(text, privacy: .private)")
        let start = Date()
        do {
            let draft = try await current.respond(to: "Descripción de la emergencia: \(text)", generating: ReportDraft.self).content
            Log.ai.info("Model answered in \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s: \(String(describing: draft), privacy: .private)")
            return Self.fields(
                forWhom: draft.forWhom, patientName: draft.patientName, reason: draft.reason, injuredCount: draft.injuredCount,
                injury: draft.injury, place: draft.place, reference: draft.reference, mentalState: draft.mentalState,
                breathing: draft.breathing, skin: draft.skin, summary: draft.summary
            )
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            // Emergency descriptions (injuries, blood) often trip the default guardrails
            Log.ai.notice("Guardrails blocked guided generation; retrying with permissive text mode")
            return try await permissiveExtract(text)
        }
    }

    // Permissive guardrails only apply to plain-text answers, so the model returns JSON as text
    private func permissiveExtract(_ text: String) async throws -> ExtractedFields {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: Self.instructions + " " + Self.jsonFormat)
        let start = Date()
        let answer = try await session.respond(to: "Descripción de la emergencia: \(text)").content
        Log.ai.info("Permissive answer in \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s: \(answer, privacy: .private)")

        guard let open = answer.firstIndex(of: "{"), let close = answer.lastIndex(of: "}"),
              let json = try? JSONDecoder().decode(ReportJSON.self, from: Data(answer[open...close].utf8))
        else {
            Log.ai.error("Permissive answer is not valid JSON")
            throw InvalidModelAnswer()
        }
        return Self.fields(
            forWhom: json.forWhom ?? "", patientName: json.patientName ?? "", reason: json.reason ?? "",
            injuredCount: min(max(json.injuredCount ?? 1, 1), 20), injury: json.injury ?? "", place: json.place ?? "",
            reference: json.reference ?? "", mentalState: Self.allowed(json.mentalState, EmergencyReport.mentalStates),
            breathing: Self.allowed(json.breathing, EmergencyReport.breathingOptions),
            skin: Self.allowed(json.skin, EmergencyReport.skinColors), summary: json.summary ?? ""
        )
    }

    private static let jsonFormat = """
        Responde únicamente con un objeto JSON con estas claves: \
        "forWhom" ("yo", "familiar" u "otra persona"), "patientName", "reason", "injuredCount" (número), \
        "injury", "place", "reference", "mentalState" ("Alerta", "Confundido", "Inconsciente" o ""), \
        "breathing" ("Normal", "Con dificultad", "No respira" o ""), "skin" ("Normal", "Pálida", "Azulada" o ""), \
        "summary" (una o dos oraciones). Usa "" para lo que no se mencione.
        """

    private struct InvalidModelAnswer: LocalizedError {
        var errorDescription: String? { "respuesta en formato inválido" }
    }

    private struct ReportJSON: Decodable {
        let forWhom: String?
        let patientName: String?
        let reason: String?
        let injuredCount: Int?
        let injury: String?
        let place: String?
        let reference: String?
        let mentalState: String?
        let breathing: String?
        let skin: String?
        let summary: String?
    }

    // Keeps only values the form offers, since plain-text answers aren't constrained
    private static func allowed(_ value: String?, _ options: [String]) -> String {
        guard let value else { return "" }
        return options.first { $0.caseInsensitiveCompare(value) == .orderedSame } ?? ""
    }

    private static func fields(
        forWhom: String, patientName: String, reason: String, injuredCount: Int, injury: String, place: String,
        reference: String, mentalState: String, breathing: String, skin: String, summary: String
    ) -> ExtractedFields {
        ExtractedFields(
            reportingFor: reportingFor(forWhom),
            patientName: nonEmpty(patientName),
            reason: nonEmpty(reason),
            injuredCount: injuredCount,
            injury: nonEmpty(injury),
            place: nonEmpty(place),
            reference: nonEmpty(reference),
            mentalState: nonEmpty(mentalState),
            breathing: nonEmpty(breathing),
            skin: nonEmpty(skin),
            summary: nonEmpty(summary),
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
