import Foundation

// Last guides received from GET /guides; without them the bundled copy keeps the emergency flow working offline
struct GuideCache: Sendable {
    let file: URL

    init(directory: URL? = nil) {
        let folder = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = folder.appending(path: "guides.json")
    }

    func load() -> [FirstAidGuide] {
        guard let data = try? Data(contentsOf: file),
              let guides = try? JSONDecoder().decode([FirstAidGuide].self, from: data),
              !guides.isEmpty else { return FirstAidGuide.bundled }
        return guides
    }

    // An empty answer is ignored so a bad server response can never leave the app without guides
    func save(_ guides: [FirstAidGuide]) {
        guard !guides.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(guides).write(to: file, options: .atomic)
        } catch {
            print("Could not cache the guides: \(error)")
        }
    }
}
