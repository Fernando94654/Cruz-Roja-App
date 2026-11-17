import Foundation

// Guarda el perfil en el teléfono para usarlo sin internet
struct MedicalProfileCache: Sendable {
    let file: URL

    init(directory: URL? = nil) {
        let folder = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = folder.appending(path: "medical-profile.json")
    }

    func load() -> MedicalProfile? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(MedicalProfile.self, from: data)
    }

    func save(_ profile: MedicalProfile) {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(profile)
            try data.write(to: file, options: [.atomic, .completeFileProtection])
        } catch {
            print("Could not cache the medical profile: \(error)")
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: file)
    }
}
