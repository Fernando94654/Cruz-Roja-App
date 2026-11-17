import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Short summary of how the family is doing, shown at the top of the Familia tab
struct FamilySummary: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case ai
        case rules
    }

    let text: String
    let source: Source
}

@MainActor
protocol FamilySummarizing: AnyObject {
    func summarize(_ family: Family) async -> FamilySummary
}

// Uses Apple's on-device model when the iPhone has Apple Intelligence; otherwise builds the summary with rules,
// so the card always shows something
@MainActor
final class FallbackFamilySummarizer: FamilySummarizing {
    private let rules = RuleBasedFamilySummarizer()

    func summarize(_ family: Family) async -> FamilySummary {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            let summary = await FoundationModelFamilySummarizer().summarize(family)
            if !summary.text.isEmpty { return summary }
        } else {
            Log.ai.notice("Family summary using rules: on-device model unavailable")
        }
        #endif
        return await rules.summarize(family)
    }
}

#if canImport(FoundationModels)
// Same idea as the alerts summary: the model runs on the iPhone and nothing is sent to the internet
@available(iOS 26.0, *)
@MainActor
final class FoundationModelFamilySummarizer: FamilySummarizing {
    private static let instructions = """
        Eres el asistente del círculo familiar de Enlace Vital, la app de la Cruz Roja Mexicana. \
        Recibes la lista de familiares del usuario con su estado. Escribe un resumen de máximo 3 oraciones \
        cortas, en español y con tono calmado. Menciona primero a quien necesita ayuda, después a quien no ha \
        contestado y al final a quien está bien. Termina con una recomendación concreta. Usa solo los nombres \
        y datos que recibes; no inventes nada. Responde solo con el resumen, sin títulos ni viñetas.
        """

    // Returns empty text if the model fails, so FallbackFamilySummarizer uses the rules
    func summarize(_ family: Family) async -> FamilySummary {
        // A new session each time so old summaries don't mix in
        let session = LanguageModelSession(instructions: Self.instructions)
        do {
            let answer = try await session.respond(to: Self.prompt(for: family)).content
            return FamilySummary(text: answer.trimmingCharacters(in: .whitespacesAndNewlines), source: .ai)
        } catch {
            Log.ai.error("Family summary failed: \(String(reflecting: error), privacy: .public)")
            return FamilySummary(text: "", source: .ai)
        }
    }

    static func prompt(for family: Family) -> String {
        guard !family.members.isEmpty else { return "El usuario todavía no tiene familiares." }
        var lines = ["Familiares del usuario:"]
        for member in family.members {
            let location = member.sharedCoordinate == nil ? "no comparte su ubicación" : "comparte su ubicación"
            lines.append("- \(member.firstName): \(RuleBasedFamilySummarizer.label(member.status)), \(location)")
        }
        return lines.joined(separator: "\n")
    }
}
#endif

// Summary without AI: groups the family by status and picks a recommendation
@MainActor
final class RuleBasedFamilySummarizer: FamilySummarizing {
    func summarize(_ family: Family) async -> FamilySummary {
        FamilySummary(text: Self.text(for: family), source: .rules)
    }

    static func text(for family: Family) -> String {
        let members = family.members
        guard !members.isEmpty else {
            return "Todavía no tienes familiares. Agrega a alguien para saber cómo está en una emergencia."
        }
        let needHelp = names(members, .needHelp)
        let waiting = names(members, .waiting)
        let unknown = names(members, .unknown)
        let ok = names(members, .ok)

        // Most urgent first
        var sentences: [String] = []
        if !needHelp.isEmpty { sentences.append("\(list(needHelp)) \(needHelp.count == 1 ? "necesita" : "necesitan") ayuda.") }
        if !waiting.isEmpty { sentences.append("\(list(waiting)) no \(waiting.count == 1 ? "ha" : "han") contestado.") }
        if !unknown.isEmpty { sentences.append("No tienes noticias de \(list(unknown)).") }
        if !ok.isEmpty { sentences.append("\(list(ok)) \(ok.count == 1 ? "está" : "están") bien.") }

        if !needHelp.isEmpty {
            sentences.append("Llama a \(needHelp[0]) o repórtalo desde su ficha.")
        } else if !waiting.isEmpty {
            sentences.append("Espera unos minutos o llámale a \(waiting[0]).")
        } else if !unknown.isEmpty {
            sentences.append("Pregúntale a \(unknown[0]) si está bien.")
        } else {
            sentences.append("Toda tu familia está bien.")
        }
        return sentences.joined(separator: " ")
    }

    static func label(_ status: MemberStatus) -> String {
        switch status {
        case .ok: "está bien"
        case .needHelp: "necesita ayuda"
        case .waiting: "no ha contestado si está bien"
        case .unknown: "sin noticias"
        }
    }

    private static func names(_ members: [FamilyMember], _ status: MemberStatus) -> [String] {
        members.filter { $0.status == status }.map(\.firstName)
    }

    // ["Ana", "Jorge", "Lucía"] -> "Ana, Jorge y Lucía"
    private static func list(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " y " + names[names.count - 1]
    }
}
