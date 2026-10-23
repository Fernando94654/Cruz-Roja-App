import Foundation

protocol DependentProfilesServicing: Sendable {
    func fetchDependents(userID: UUID) async throws -> [DependentProfile]
    func createDependent(_ dependent: DependentProfile, userID: UUID) async throws -> DependentProfile
    func updateDependent(_ dependent: DependentProfile, userID: UUID) async throws -> DependentProfile
    func deleteDependent(id: UUID, userID: UUID) async throws
}

// /users/{id}/dependents (GET, POST) and /users/{id}/dependents/{dependent_id} (PUT, DELETE)
struct DependentProfilesAPIService: DependentProfilesServicing {
    var client = APIClient()

    func fetchDependents(userID: UUID) async throws -> [DependentProfile] {
        // A 404 here means the user doesn't exist; show an empty list
        try await client.get(path(userID), as: [DependentProfile].self) ?? []
    }

    func createDependent(_ dependent: DependentProfile, userID: UUID) async throws -> DependentProfile {
        try await client.post(path(userID), body: dependent, as: DependentProfile.self)
    }

    func updateDependent(_ dependent: DependentProfile, userID: UUID) async throws -> DependentProfile {
        try await client.put(path(userID, dependent.id), body: dependent, as: DependentProfile.self)
    }

    func deleteDependent(id: UUID, userID: UUID) async throws {
        try await client.delete(path(userID, id))
    }

    private func path(_ userID: UUID, _ dependentID: UUID? = nil) -> String {
        let base = "users/\(userID.uuidString.lowercased())/dependents"
        guard let dependentID else { return base }
        return "\(base)/\(dependentID.uuidString.lowercased())"
    }
}

actor MockDependentProfilesService: DependentProfilesServicing {
    private var dependents: [DependentProfile]

    init(dependents: [DependentProfile] = [.sample]) {
        self.dependents = dependents
    }

    func fetchDependents(userID: UUID) async throws -> [DependentProfile] {
        dependents
    }

    func createDependent(_ dependent: DependentProfile, userID: UUID) async throws -> DependentProfile {
        var saved = dependent
        saved.id = UUID()
        saved.profile.updatedAt = Date()
        dependents.append(saved)
        return saved
    }

    func updateDependent(_ dependent: DependentProfile, userID: UUID) async throws -> DependentProfile {
        guard let index = dependents.firstIndex(where: { $0.id == dependent.id }) else {
            throw APIError.server(status: 404, message: "Familiar no encontrado")
        }
        var saved = dependent
        saved.profile.updatedAt = Date()
        dependents[index] = saved
        return saved
    }

    func deleteDependent(id: UUID, userID: UUID) async throws {
        dependents.removeAll { $0.id == id }
    }
}

// Last list received from the API, so dependents' profiles and QR codes work offline
struct DependentProfilesCache: Sendable {
    let file: URL

    init(directory: URL? = nil) {
        let folder = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = folder.appending(path: "dependent-profiles.json")
    }

    func load() -> [DependentProfile]? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode([DependentProfile].self, from: data)
    }

    // Same protection as MedicalProfileCache: only readable while the phone is unlocked
    func save(_ dependents: [DependentProfile]) {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(dependents)
            try data.write(to: file, options: [.atomic, .completeFileProtection])
        } catch {
            print("Could not cache the dependent profiles: \(error)")
        }
    }
}
