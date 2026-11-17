import Foundation

// Perfil médico de un familiar
struct DependentProfile: Identifiable, Equatable, Sendable {
    var id = UUID()
    var relationship: String = ""
    var profile = MedicalProfile()

    static let maxDependents = 10

    var fullName: String { profile.fullName }

    var displayName: String {
        relationship.isEmpty ? profile.fullName : "\(profile.fullName) (\(relationship))"
    }
}

extension DependentProfile {
    var validationErrors: [String] {
        var errors: [String] = []
        if relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Escribe el parentesco (por ejemplo Mamá o Hijo).")
        }
        return errors + profile.validationErrors
    }

    var isValid: Bool { validationErrors.isEmpty }

    func cleaned() -> DependentProfile {
        var copy = self
        copy.relationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.profile = profile.cleaned()
        return copy
    }
}

extension DependentProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, relationship
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        relationship = try c.decodeIfPresent(String.self, forKey: .relationship) ?? ""
        profile = try MedicalProfile(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try profile.encode(to: encoder)
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(relationship, forKey: .relationship)
    }
}

extension DependentProfile {
    static let sample = DependentProfile(
        relationship: "Abuela",
        profile: MedicalProfile(
            fullName: "Rosa Martínez",
            dateOfBirth: MedicalProfile.dayFormatter.date(from: "1945-07-02"),
            bloodType: .aPositive,
            allergies: ["Sulfas"],
            conditions: ["Diabetes tipo 2", "Hipertensión"],
            medications: ["Metformina", "Losartán"],
            contacts: [EmergencyContact(name: "Luis Martínez", relationship: "Hijo", phone: "8123456789")]
        )
    )
}
