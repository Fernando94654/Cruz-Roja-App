#if canImport(FoundationModels)
import Foundation
import FoundationModels

// Resume las alertas con el modelo de lenguaje de Apple, que corre en el iPhone sin enviar datos a internet
@available(iOS 26.0, *)
@MainActor
final class FoundationModelAlertsSummarizer: AlertsSummarizing {
    private static let instructions = """
        Eres el asistente de alertas de Enlace Vital, la app de la Cruz Roja Mexicana. Recibes las alertas \
        oficiales y los reportes de vecinos que ve el usuario. Escribe un resumen para leerse en voz alta: \
        máximo 3 oraciones cortas, en español y con tono calmado. Menciona primero lo más grave, después lo \
        que reportan los vecinos, y termina con una recomendación de seguridad concreta. Usa solo la \
        información que recibes; no inventes lugares, cifras ni horarios. Si no hay alertas ni reportes, \
        dilo y recomienda mantenerse atento. Responde solo con el resumen, sin títulos ni viñetas.
        """

    // Limites para que la peticion quepa en el contexto del modelo
    private static let maxAlerts = 8
    private static let maxReports = 10
    private static let maxDescription = 200

    // Regresa texto vacio si el modelo falla, para que FallbackAlertsSummarizer use las reglas
    func summarize(_ snapshot: AlertsSnapshot) async -> AlertsSummary {
        // Una sesion nueva por resumen evita que se mezclen resumenes anteriores
        let session = LanguageModelSession(instructions: Self.instructions)
        let start = Date()
        do {
            let answer = try await session.respond(to: Self.prompt(for: snapshot)).content
            Log.ai.info("Alerts summary in \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s")
            let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            return AlertsSummary(text: text, source: .ai)
        } catch {
            Log.ai.error("Alerts summary failed: \(String(reflecting: error), privacy: .public)")
            return AlertsSummary(text: "", source: .ai)
        }
    }

    static func prompt(for snapshot: AlertsSnapshot) -> String {
        let scope = snapshot.scope == .myArea ? "la zona del usuario" : "todo México"
        var lines = ["Alertas oficiales vigentes en \(scope):"]
        if snapshot.officialAlerts.isEmpty { lines.append("- Ninguna") }
        for alert in snapshot.officialAlerts.prefix(maxAlerts) {
            var line = "- [\(alert.severity.label)] \(alert.title) (\(alert.source), \(alert.areaName))"
            if let message = alert.message { line += ": \(message.prefix(maxDescription))" }
            lines.append(line)
        }
        lines.append("Reportes de vecinos cercanos de las últimas horas:")
        if snapshot.reports.isEmpty { lines.append("- Ninguno") }
        for report in snapshot.reports.prefix(maxReports) {
            let confirmed = report.isConfirmed ? ", confirmado por \(report.confirmations) vecinos" : ""
            lines.append("- \(report.category.label): \(report.title)\(confirmed)")
        }
        return lines.joined(separator: "\n")
    }
}
#endif
