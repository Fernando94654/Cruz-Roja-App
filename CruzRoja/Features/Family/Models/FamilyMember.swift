import Foundation

struct FamilyMember: Identifiable, Hashable, Sendable {
    var id = UUID()
    let name: String
    let status: String
    let hasAlert: Bool
    let coordinate: Coordinate
}

// Heart-rate alert raised by a member's Apple Watch
struct FamilyAlert: Hashable, Sendable {
    let memberName: String
    let title: String
    let detail: String
    let reason: String
}

extension FamilyMember {
    static let samples = [
        FamilyMember(name: "Mamá", status: "Alerta activa", hasAlert: true,
                     coordinate: Coordinate(latitude: 25.6600, longitude: -100.3000)),
        FamilyMember(name: "Papá", status: "Bien · hace 1 h", hasAlert: false,
                     coordinate: Coordinate(latitude: 25.6450, longitude: -100.2800)),
        FamilyMember(name: "Hermana", status: "Bien · hace 3 h", hasAlert: false,
                     coordinate: Coordinate(latitude: 25.6700, longitude: -100.3100)),
    ]
}

extension FamilyAlert {
    static let sample = FamilyAlert(
        memberName: "Mamá",
        title: "Mamá registró un ritmo cardiaco anormal",
        detail: "Hace 2 min · Apple Watch",
        reason: "Ritmo cardiaco anormal"
    )
}
