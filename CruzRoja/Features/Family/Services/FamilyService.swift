import Foundation

// Every call returns the whole family so the screen just redraws
protocol FamilyServicing: Sendable {
    func fetchFamily() async throws -> Family
    func askIfOK(memberID: UUID) async throws -> Family
    func answer(_ answer: WellbeingAnswer) async throws -> Family
    func invite(name: String, contact: String, relationship: String) async throws -> Family
    func cancelInvitation(id: UUID) async throws -> Family
    func respondToInvitation(id: UUID, accept: Bool) async throws -> Family
    func removeMember(id: UUID) async throws -> Family
    func setSharesLocation(_ shares: Bool) async throws -> Family
}

// /family in backend/app/routers/family.py, the server knows who I am by the sign-in token
struct FamilyAPIService: FamilyServicing {
    var client = APIClient()

    private struct InvitationBody: Encodable {
        let name: String
        let contact: String
        let relationship: String
    }

    private struct AnswerBody: Encodable {
        let status: WellbeingAnswer
    }

    private struct SharingBody: Encodable {
        let sharesLocation: Bool

        enum CodingKeys: String, CodingKey {
            case sharesLocation = "shares_location"
        }
    }

    func fetchFamily() async throws -> Family {
        try await client.get(path(), as: Family.self) ?? Family()
    }

    func askIfOK(memberID: UUID) async throws -> Family {
        try await client.post(path("members/\(id(memberID))/wellbeing-check"))
    }

    func answer(_ answer: WellbeingAnswer) async throws -> Family {
        try await client.post(path("wellbeing-answer"), body: AnswerBody(status: answer))
    }

    func invite(name: String, contact: String, relationship: String) async throws -> Family {
        try await client.post(path("invitations"),
                              body: InvitationBody(name: name, contact: contact, relationship: relationship))
    }

    func cancelInvitation(id invitationID: UUID) async throws -> Family {
        try await client.delete(path("invitations/\(id(invitationID))"))
    }

    func respondToInvitation(id invitationID: UUID, accept: Bool) async throws -> Family {
        try await client.post(path("invitations/\(id(invitationID))/\(accept ? "accept" : "decline")"))
    }

    func removeMember(id memberID: UUID) async throws -> Family {
        try await client.delete(path("members/\(id(memberID))"))
    }

    func setSharesLocation(_ shares: Bool) async throws -> Family {
        try await client.put(path("sharing"), body: SharingBody(sharesLocation: shares))
    }

    private func path(_ rest: String = "") -> String {
        rest.isEmpty ? "family" : "family/\(rest)"
    }

    private func id(_ uuid: UUID) -> String {
        uuid.uuidString.lowercased()
    }
}

// Previews and -demo family, works without the server
actor MockFamilyService: FamilyServicing {
    private var family: Family
    // Simulated family members answer "¿Estás bien?" this long after being asked
    private let answerDelay: TimeInterval
    private var askedAt: [UUID: Date] = [:]

    init(family: Family = .sample(), answerDelay: TimeInterval = 6) {
        self.family = family
        self.answerDelay = answerDelay
    }

    func fetchFamily() async throws -> Family {
        for (id, date) in askedAt where Date().timeIntervalSince(date) >= answerDelay {
            if let i = family.members.firstIndex(where: { $0.id == id }) {
                family.members[i].status = .ok
                family.members[i].updatedAt = Date()
            }
            askedAt[id] = nil
        }
        return family
    }

    func askIfOK(memberID: UUID) async throws -> Family {
        if let i = family.members.firstIndex(where: { $0.id == memberID }) {
            family.members[i].status = .waiting
            family.members[i].updatedAt = Date()
            askedAt[memberID] = Date()
        }
        return family
    }

    func answer(_ answer: WellbeingAnswer) async throws -> Family {
        family.wellbeingRequest = nil
        return family
    }

    func invite(name: String, contact: String, relationship: String) async throws -> Family {
        let invitation = FamilyInvitation(id: UUID(), name: name, contact: contact, relationship: relationship,
                                          sentAt: Date(), expiresAt: Date().addingTimeInterval(7 * 86400))
        family.sentInvitations.insert(invitation, at: 0)
        return family
    }

    func cancelInvitation(id: UUID) async throws -> Family {
        family.sentInvitations.removeAll { $0.id == id }
        return family
    }

    func respondToInvitation(id: UUID, accept: Bool) async throws -> Family {
        guard let i = family.receivedInvitations.firstIndex(where: { $0.id == id }) else { return family }
        let invitation = family.receivedInvitations.remove(at: i)
        if accept, let name = invitation.fromName {
            family.members.append(FamilyMember(id: UUID(), name: name, phone: "8110000005", status: .unknown,
                                               updatedAt: Date(), sharesLocation: true,
                                               coordinate: Coordinate(latitude: 25.6380, longitude: -100.3050)))
        }
        return family
    }

    func removeMember(id: UUID) async throws -> Family {
        family.members.removeAll { $0.id == id }
        return family
    }

    func setSharesLocation(_ shares: Bool) async throws -> Family {
        family.sharesLocation = shares
        return family
    }
}
