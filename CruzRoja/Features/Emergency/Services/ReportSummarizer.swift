import Foundation

// Short summary for the operator built from the report fields
enum ReportSummarizer {
    /// Builds a one-line summary from the filled fields.
    static func summarize(_ report: EmergencyReport) -> String {
        var headline = report.reason.isEmpty ? "Emergencia" : report.reason
        if !report.place.isEmpty { headline += " en \(report.place.lowercased())" }
        headline += ", \(report.injuredCount) \(report.injuredCount == 1 ? "lesionado" : "lesionados")"
        if !report.injury.isEmpty { headline += " con \(report.injury.lowercased())" }

        var vitals: [String] = []
        if !report.mentalState.isEmpty { vitals.append(report.mentalState.lowercased()) }
        switch report.breathing {
        case "Normal": vitals.append("respira normal")
        case "Con dificultad": vitals.append("respira con dificultad")
        case "No respira": vitals.append("no respira")
        default: break
        }
        if !report.skin.isEmpty, report.skin != "Normal" { vitals.append("piel \(report.skin.lowercased())") }

        var summary = report.patientName.map { "\($0): " } ?? ""
        summary += headline
        if !vitals.isEmpty { summary += "; " + vitals.joined(separator: ", ") }
        summary += "."
        if !report.reference.isEmpty { summary += " Referencia: \(report.reference)." }
        return summary
    }
}
