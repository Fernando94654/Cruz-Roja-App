import Foundation

// Saves the downloaded texts; the app also ships a copy in case there is no internet
struct KnowledgeCache: Sendable {
    let file: URL
    let bundled: URL?

    init(directory: URL? = nil, bundled: URL? = Bundle.main.url(forResource: "knowledge", withExtension: "json")) {
        let folder = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = folder.appending(path: "knowledge.json")
        self.bundled = bundled
    }

    // Uses the downloaded copy, otherwise the one in the app
    func load() -> [KnowledgeChunk] {
        for url in [file, bundled].compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let chunks = try? JSONDecoder().decode([KnowledgeChunk].self, from: data),
               !chunks.isEmpty {
                return chunks
            }
        }
        return []
    }

    // Doesn't save an empty list so it never deletes what was there
    func save(_ chunks: [KnowledgeChunk]) {
        guard !chunks.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(chunks).write(to: file, options: .atomic)
        } catch {
            print("Could not cache the knowledge base: \(error)")
        }
    }
}
