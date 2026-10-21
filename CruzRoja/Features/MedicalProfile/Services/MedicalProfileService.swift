import Foundation

protocol MedicalProfileServicing: Sendable {
    // Returns nil when the user has no profile yet
    func fetchProfile(userID: UUID) async throws -> MedicalProfile?
    // Creates or replaces the profile and returns what was stored
    func saveProfile(_ profile: MedicalProfile, userID: UUID) async throws -> MedicalProfile
}

// GET and PUT /users/{id}/medical-profile
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
