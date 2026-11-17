import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Resumen de las alertas y reportes que ve el usuario, listo para leerse en voz alta
struct AlertsSummary: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case ai
        case rules
    }

    let text: String
    let source: Source
}

// Lo que se resume: las alertas oficiales que estan en pantalla y los reportes vigentes
struct AlertsSnapshot: Sendable {
    let officialAlerts: [OfficialAlert]
    let reports: [CommunityReport]
    let scope: OfficialAlertScope
}

@MainActor
protocol AlertsSummarizing: AnyObject {
    func summarize(_ snapshot: AlertsSnapshot) async -> AlertsSummary
}

// Usa la IA de Apple en el dispositivo cuando esta disponible; si no, arma el resumen con reglas
@MainActor
final class FallbackAlertsSummarizer: AlertsSummarizing {
    private let rules = RuleBasedAlertsSummarizer()
    // Guarda un FoundationModelAlertsSummarizer; el tipo es generico porque solo existe en iOS 26
    private var model: AlertsSummarizing?

    func summarize(_ snapshot: AlertsSnapshot) async -> AlertsSummary {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            if model == nil { model = FoundationModelAlertsSummarizer() }
            if let model {
                let summary = await model.summarize(snapshot)
                if !summary.text.isEmpty { return summary }
            }
        } else {
            Log.ai.notice("Alerts summary using rules: on-device model unavailable")
        }
        #endif
        return await rules.summarize(snapshot)
    }
}

// Resumen sin IA: cuenta alertas y reportes y elige una recomendacion segun lo mas grave
@MainActor
final class RuleBasedAlertsSummarizer: AlertsSummarizing {
    func summarize(_ snapshot: AlertsSnapshot) async -> AlertsSummary {
        AlertsSummary(text: Self.text(for: snapshot), source: .rules)
    }

    static func text(for snapshot: AlertsSnapshot) -> String {
        [officialSentence(snapshot), reportsSentence(snapshot.reports), tip(for: snapshot)].joined(separator: " ")
    }

    private static func officialSentence(_ snapshot: AlertsSnapshot) -> String {
        let place = snapshot.scope == .myArea ? "en tu zona" : "en México"
        guard let worst = mostSevere(snapshot.officialAlerts) else {
            return "No hay alertas oficiales \(place)."
        }
        let count = snapshot.officialAlerts.count
        let intro = count == 1 ? "Hay 1 alerta oficial \(place)" : "Hay \(count) alertas oficiales \(place)"
        let detail = count == 1 ? "" : "; la más importante"
        return "\(intro)\(detail): \(trimmed(worst.title)), nivel \(worst.severity.label.lowercased())."
    }

    private static func reportsSentence(_ reports: [CommunityReport]) -> String {
        guard !reports.isEmpty else { return "Ningún vecino ha reportado algo cerca." }
        // Categorias de la mas reportada a la menos reportada
        let counts = Dictionary(grouping: reports, by: \.category).mapValues(\.count)
        let parts = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.label < $1.key.label }
            .map { "\($0.key.label.lowercased()) (\($0.value))" }
        let confirmed = reports.filter(\.isConfirmed).count
        let confirmedText = confirmed == 0 ? "" : confirmed == 1 ? ", 1 ya confirmado" : ", \(confirmed) ya confirmados"
        return "Los vecinos reportan: \(list(parts))\(confirmedText)."
    }

    // Recomendacion segun la alerta oficial mas grave o, si no hay, el reporte mas comun
    private static func tip(for snapshot: AlertsSnapshot) -> String {
        if let worst = mostSevere(snapshot.officialAlerts) {
            let text = "\(worst.title) \(worst.message ?? "")".lowercased()
            if text.contains("ciclón") || text.contains("huracán") || text.contains("tormenta tropical") {
                return "Ten lista tu mochila de emergencia y sigue las indicaciones de Protección Civil."
            }
            if text.contains("lluvia") || text.contains("inunda") || text.contains("tormenta") {
                return "Evita cruzar calles y arroyos inundados."
            }
            if text.contains("frío") || text.contains("helada") || text.contains("temperatura") {
                return "Abrígate y no uses anafres ni braseros en lugares cerrados."
            }
            if text.contains("calor") {
                return "Toma agua y evita el sol entre las 11 y las 17 horas."
            }
            if text.contains("viento") {
                return "Aléjate de árboles, anuncios y cables."
            }
        }
        let counts = Dictionary(grouping: snapshot.reports, by: \.category).mapValues(\.count)
        switch counts.max(by: { $0.value < $1.value })?.key {
        case .flood: return "Evita cruzar calles inundadas."
        case .fire: return "Aléjate del humo y llama al 911 si ves fuego."
        case .powerOutage: return "Desconecta tus aparatos hasta que vuelva la luz."
        case .fallenTree: return "No toques cables caídos y rodea la zona."
        case .accident, .blockedStreet, .trafficLight: return "Maneja con precaución y usa rutas alternas."
        case .other, nil: return "Mantente atento a nuevas alertas."
        }
    }

    private static func mostSevere(_ alerts: [OfficialAlert]) -> OfficialAlert? {
        let rank = AlertSeverity.allCases
        return alerts.max { (rank.firstIndex(of: $0.severity) ?? 0) < (rank.firstIndex(of: $1.severity) ?? 0) }
    }

    // Quita el punto final para que el titulo quepa dentro de la oracion
    private static func trimmed(_ title: String) -> String {
        title.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).trimmingCharacters(in: .whitespaces)
    }

    private static func list(_ parts: [String]) -> String {
        guard parts.count > 1 else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " y " + parts[parts.count - 1]
    }
}
