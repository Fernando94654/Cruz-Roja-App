import Foundation

struct OfficialAlert: Identifiable, Hashable, Sendable {
    var id = UUID()
    var source: String
    var title: String
    var message: String?
    var areaName: String
    var issuedAt: Date
    var icon = "exclamationmark.triangle.fill"
}

// Raw values match the backend's community_report_type enum
enum CommunityReportCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case flood
    case blockedStreet = "blocked_street"
    case fallenTree = "fallen_tree"
    case powerOutage = "power_outage"
    case fire
    case trafficLight = "traffic_light"
    case accident
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flood: "Inundación"
        case .blockedStreet: "Calle bloqueada"
        case .fallenTree: "Árbol caído"
        case .powerOutage: "Apagón"
        case .fire: "Incendio"
        case .trafficLight: "Semáforo"
        case .accident: "Accidente"
        case .other: "Otro"
        }
    }
}

struct CommunityReport: Identifiable, Hashable, Sendable {
    var id = UUID()
    var category: CommunityReportCategory
    var title: String
    var confirmations: Int
    var confirmedByMe = false
    var expiresAt: Date
}

extension OfficialAlert {
    static func samples(now: Date = Date()) -> [OfficialAlert] {
        [
            OfficialAlert(source: "Protección Civil NL",
                          title: "Lluvia intensa en tu zona",
                          message: "Evita cruzar calles inundadas y mantente en un lugar seguro.",
                          areaName: "Monterrey",
                          issuedAt: now.addingTimeInterval(-20 * 60),
                          icon: "cloud.heavyrain.fill"),
            OfficialAlert(source: "SMN",
                          title: "Lluvias intensas en el área metropolitana",
                          areaName: "San Nicolás",
                          issuedAt: now.addingTimeInterval(-2 * 3600),
                          icon: "cloud.heavyrain.fill"),
        ]
    }
}

extension CommunityReport {
    static func samples(now: Date = Date()) -> [CommunityReport] {
        [
            CommunityReport(category: .flood, title: "Calle inundada a 400 m",
                            confirmations: 6, expiresAt: now.addingTimeInterval(3 * 3600)),
            CommunityReport(category: .trafficLight, title: "Semáforo apagado en el cruce",
                            confirmations: 2, expiresAt: now.addingTimeInterval(2 * 3600)),
            CommunityReport(category: .fallenTree, title: "Árbol bloqueando un carril",
                            confirmations: 1, expiresAt: now.addingTimeInterval(2 * 3600)),
        ]
    }
}
