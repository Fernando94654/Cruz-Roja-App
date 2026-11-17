import Foundation

// Trae y guarda el perfil médico del usuario que inició sesión
protocol MedicalProfileServicing: Sendable {
    func fetchProfile() async throws -> MedicalProfile?
    func saveProfile(_ profile: MedicalProfile) async throws -> MedicalProfile
}

// Versión real: se conecta al API
struct MedicalProfileAPIService: MedicalProfileServicing {
    var client = APIClient()

    // El servidor sabe de quién es el perfil por el inicio de sesión
    private let path = "me/medical-profile"

    func fetchProfile() async throws -> MedicalProfile? {
        try await client.get(path, as: MedicalProfile.self)
    }

    func saveProfile(_ profile: MedicalProfile) async throws -> MedicalProfile {
        try await client.put(path, body: profile, as: MedicalProfile.self)
    }
}

// Versión de prueba: funciona sin el API
actor MockMedicalProfileService: MedicalProfileServicing {
    private var profile: MedicalProfile?

    init(profile: MedicalProfile? = .sample) {
        self.profile = profile
    }

    func fetchProfile() async throws -> MedicalProfile? {
        profile
    }

    func saveProfile(_ profile: MedicalProfile) async throws -> MedicalProfile {
        var saved = profile
        saved.updatedAt = Date()
        self.profile = saved
        return saved
    }
}
