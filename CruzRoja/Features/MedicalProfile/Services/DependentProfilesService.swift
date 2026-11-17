import Foundation

// Trae, agrega, edita y borra los familiares del usuario que inició sesión
protocol DependentProfilesServicing: Sendable {
    func fetchDependents() async throws -> [DependentProfile]
    func createDependent(_ dependent: DependentProfile) async throws -> DependentProfile
    func updateDependent(_ dependent: DependentProfile) async throws -> DependentProfile
    func deleteDependent(id: UUID) async throws
}

// Versión real: se conecta al API
struct DependentProfilesAPIService: DependentProfilesServicing {
    var client = APIClient()

    func fetchDependents() async throws -> [DependentProfile] {
        try await client.get(path(), as: [DependentProfile].self) ?? []
    }

    func createDependent(_ dependent: DependentProfile) async throws -> DependentProfile {
        try await client.post(path(), body: dependent, as: DependentProfile.self)
    }

    func updateDependent(_ dependent: DependentProfile) async throws -> DependentProfile {
        try await client.put(path(dependent.id), body: dependent, as: DependentProfile.self)
    }

    func deleteDependent(id: UUID) async throws {
        try await client.delete(path(id))
    }

    // El servidor sabe de quién son los familiares por el inicio de sesión
    private func path(_ dependentID: UUID? = nil) -> String {
        guard let dependentID else { return "me/dependents" }
        return "me/dependents/\(dependentID.uuidString.lowercased())"
    }
}

// Versión de prueba: funciona sin el API
actor MockDependentProfilesService: DependentProfilesServicing {
    private var dependents: [DependentProfile]

    init(dependents: [DependentProfile] = [.sample]) {
        self.dependents = dependents
    }

    func fetchDependents() async throws -> [DependentProfile] {
        dependents
    }

    func createDependent(_ dependent: DependentProfile) async throws -> DependentProfile {
        var saved = dependent
        saved.id = UUID()
        saved.profile.updatedAt = Date()
        dependents.append(saved)
        return saved
    }

    func updateDependent(_ dependent: DependentProfile) async throws -> DependentProfile {
        guard let index = dependents.firstIndex(where: { $0.id == dependent.id }) else {
            throw APIError.server(status: 404, message: "Familiar no encontrado")
        }
        var saved = dependent
        saved.profile.updatedAt = Date()
        dependents[index] = saved
        return saved
    }

    func deleteDependent(id: UUID) async throws {
        dependents.removeAll { $0.id == id }
    }
}

// Guarda la lista en el teléfono para usarla sin internet
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

    func save(_ dependents: [DependentProfile]) {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(dependents)
            try data.write(to: file, options: [.atomic, .completeFileProtection])
        } catch {
            print("Could not cache the dependent profiles: \(error)")
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: file)
    }
}
