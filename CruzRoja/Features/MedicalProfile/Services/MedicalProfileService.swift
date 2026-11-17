import Foundation

// Trae y guarda el perfil médico
protocol MedicalProfileServicing: Sendable {
    func fetchProfile(userID: UUID) async throws -> MedicalProfile?
    func saveProfile(_ profile: MedicalProfile, userID: UUID) async throws -> MedicalProfile
}

// Versión real: se conecta al API
struct MedicalProfileAPIService: MedicalProfileServicing {
    var client = APIClient()

    func fetchProfile(userID: UUID) async throws -> MedicalProfile? {
        try await client.get(path(userID), as: MedicalProfile.self)
    }

    func saveProfile(_ profile: MedicalProfile, userID: UUID) async throws -> MedicalProfile {
        try await client.put(path(userID), body: profile, as: MedicalProfile.self)
    }

    private func path(_ userID: UUID) -> String {
        "users/\(userID.uuidString.lowercased())/medical-profile"
    }
}

// Versión de prueba: funciona sin el API
actor MockMedicalProfileService: MedicalProfileServicing {
    private var profile: MedicalProfile?

    init(profile: MedicalProfile? = .sample) {
        self.profile = profile
    }

    func fetchProfile(userID: UUID) async throws -> MedicalProfile? {
        profile
    }

    func saveProfile(_ profile: MedicalProfile, userID: UUID) async throws -> MedicalProfile {
        var saved = profile
        saved.userID = userID
        saved.updatedAt = Date()
        self.profile = saved
        return saved
    }
}
