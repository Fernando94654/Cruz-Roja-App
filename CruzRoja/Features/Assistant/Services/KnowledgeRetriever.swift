import Foundation

// Finds the texts closest to the question using cosine similarity
actor KnowledgeRetriever {
    private let cache: KnowledgeCache
    private var embedder: Embedder?
    private var chunks: [KnowledgeChunk] = []

    struct NoModel: Error {}

    init(cache: KnowledgeCache) {
        self.cache = cache
    }

    // Loads the model and the texts only once, it takes a few seconds
    func load() {
        guard embedder == nil else { return }
        embedder = Embedder.bundled()
        chunks = cache.load().filter { $0.embedding != nil }
    }

    func search(_ question: String, k: Int = 4) throws -> [KnowledgeChunk] {
        load()
        guard let embedder else { throw NoModel() }
        let query = try embedder.embedQuery(question)
        let ranked = chunks
            .map { (chunk: $0, score: cosine(query, $0.embedding ?? [])) }
            .sorted { $0.score > $1.score }
            .prefix(k)
        let summary = ranked.map { "\($0.chunk.id) \(String(format: "%.3f", $0.score))" }.joined(separator: ", ")
        Log.ai.info("Top \(k) chunks: \(summary, privacy: .public)")
        return ranked.map(\.chunk)
    }

    // Vectors are already normalized so the dot product is enough
    private func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return -1 }
        return zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }
}
