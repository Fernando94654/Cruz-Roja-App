import Foundation

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
}

struct EmergencyReport: Hashable, Sendable {
    var reportingFor: ReportingFor = .myself
    var patientName: String?
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

    // Fixed result until on-device speech recognition and AI extraction exist
    mutating func applyDictationSample() {
        reason = "Caída en casa"
        injuredCount = 1
        injury = "Golpe en la cabeza"
        place = "Casa habitación"
        reference = "2.º piso, puerta azul"
        mentalState = "Confundido"
        breathing = "Normal"
        skin = "Pálida"
    }
}

struct EmergencyLocation: Hashable, Sendable {
    let coordinate: Coordinate
    let address: String
    let accuracyMeters: Int

    // Fixed until CoreLocation is wired
    static let current = EmergencyLocation(
        coordinate: .monterrey,
        address: "Av. Eugenio Garza Sada 2501 Sur, Monterrey, N.L.",
        accuracyMeters: 5
    )
}
