import Foundation

// Same values as MemberStatus in backend/app/schemas/family.py
enum MemberStatus: String, Codable, Hashable, Sendable {
    case ok
    case needHelp = "need_help"
    case waiting
    case unknown
}

enum WellbeingAnswer: String, Encodable, Sendable {
    case ok
    case needHelp = "need_help"
}

struct FamilyMember: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: String
    var relationship: String?
    var phone: String?
    var status: MemberStatus
    var updatedAt: Date
    var sharesLocation: Bool
    var coordinate: Coordinate?

    enum CodingKeys: String, CodingKey {
        case id, name, relationship, phone, status, coordinate
        case updatedAt = "updated_at"
        case sharesLocation = "shares_location"
    }
}

struct FamilyInvitation: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: String
    let contact: String
    var relationship: String?
    // Who sent it, only on the ones I received
    var fromName: String?
    let sentAt: Date
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, contact, relationship
        case fromName = "from_name"
        case sentAt = "sent_at"
        case expiresAt = "expires_at"
    }
}

// "¿Estás bien?" someone in my family sent me
struct WellbeingRequest: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let fromName: String
    var reason: String?
    let sentAt: Date

    enum CodingKeys: String, CodingKey {
        case id, reason
        case fromName = "from_name"
        case sentAt = "sent_at"
    }
}

// Everything the Familia screen shows, the server sends it whole after every change
struct Family: Codable, Hashable, Sendable {
    var members: [FamilyMember] = []
    var sentInvitations: [FamilyInvitation] = []
    var receivedInvitations: [FamilyInvitation] = []
    var wellbeingRequest: WellbeingRequest?
    var sharesLocation = true

    enum CodingKeys: String, CodingKey {
        case members
        case sentInvitations = "sent_invitations"
        case receivedInvitations = "received_invitations"
        case wellbeingRequest = "wellbeing_request"
        case sharesLocation = "shares_location"
    }
}

extension FamilyMember {
    static let relationships = ["Mamá", "Papá", "Hija", "Hijo", "Hermana", "Hermano", "Pareja",
                                "Abuela", "Abuelo", "Nieta", "Nieto", "Otro"]
}

// Same people as backend/scripts/seed.py, for previews and -demo family
extension Family {
    static func sample(now: Date = Date()) -> Family {
        Family(
            members: [
                FamilyMember(id: UUID(), name: "Ana López", relationship: "Hija", phone: "8112345678",
                             status: .needHelp, updatedAt: now.addingTimeInterval(-120), sharesLocation: true,
                             coordinate: Coordinate(latitude: 25.6600, longitude: -100.3000)),
                FamilyMember(id: UUID(), name: "Jorge López", relationship: "Pareja", phone: "8110000003",
                             status: .ok, updatedAt: now.addingTimeInterval(-3600), sharesLocation: true,
                             coordinate: Coordinate(latitude: 25.6450, longitude: -100.2800)),
                FamilyMember(id: UUID(), name: "Lucía López", relationship: "Hermana", phone: "8110000004",
                             status: .waiting, updatedAt: now.addingTimeInterval(-1800), sharesLocation: false),
            ],
            sentInvitations: [
                FamilyInvitation(id: UUID(), name: "Pedro López", contact: "8110000006", relationship: "Nieto",
                                 sentAt: now.addingTimeInterval(-7200), expiresAt: now.addingTimeInterval(7 * 86400)),
            ],
            receivedInvitations: [
                FamilyInvitation(id: UUID(), name: "María López", contact: "8110000001", relationship: "Otro",
                                 fromName: "Carmen Ruiz", sentAt: now.addingTimeInterval(-86400),
                                 expiresAt: now.addingTimeInterval(6 * 86400)),
            ],
            wellbeingRequest: WellbeingRequest(id: UUID(), fromName: "Jorge López", sentAt: now.addingTimeInterval(-300))
        )
    }
}

extension FamilyMember {
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    // Only when they agreed to share it
    var sharedCoordinate: Coordinate? {
        sharesLocation ? coordinate : nil
    }

    var phoneURL: URL? {
        phone.flatMap { URL(string: "tel:\($0)") }
    }

    // 8112345678 -> 81 1234 5678
    var formattedPhone: String? {
        guard let phone, phone.count == 10 else { return phone }
        let digits = Array(phone)
        return "\(String(digits[0..<2])) \(String(digits[2..<6])) \(String(digits[6...]))"
    }
}

// Opens the route in the maps app the user picks
enum Directions {
    static func appleMaps(to coordinate: Coordinate) -> URL {
        URL(string: "https://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=d")!
    }

    static func googleMaps(to coordinate: Coordinate) -> URL {
        URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(coordinate.latitude),\(coordinate.longitude)&travelmode=driving")!
    }
}
