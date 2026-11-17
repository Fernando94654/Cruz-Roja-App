import Foundation

/// Who the emergency is for.
enum ReportingFor: CaseIterable, Hashable, Sendable {
    case myself
    case someoneElse
    case familyMember

    var label: String {
        switch self {
        case .myself: "Para mí"
        case .someoneElse: "Para otra persona"
        case .familyMember: "Para un familiar"
        }
    }

    // Value expected by the backend's reporting_for enum
    var wireValue: String {
        self == .myself ? "self" : "other"
    }
}

/// Emergency report with the fields Cruz Roja asks for.
struct EmergencyReport: Hashable, Sendable {
    var reportingFor: ReportingFor = .myself
    var patientName: String?
    // Free text typed or dictated by the user
    var description = ""
    var reason = ""
    var injuredCount = 1
    var injury = ""
    var place = ""
    var reference = ""
    var mentalState = ""
    var breathing = ""
    var skin = ""

    static let mentalStates = ["Alerta", "Confundido", "Inconsciente"]
    static let breathingOptions = ["Normal", "Con dificultad", "No respira"]
    static let skinColors = ["Normal", "Pálida", "Azulada"]

    // Used by the screenshot demo modes
    static let demoDescription = "Mi abuela se cayó en la casa y se golpeó la cabeza, está confundida y pálida pero respira bien"
}

/// Exact location sent with the report.
struct EmergencyLocation: Hashable, Sendable {
    let coordinate: Coordinate
    let address: String
    let accuracyMeters: Int
}
