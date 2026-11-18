import Foundation

// Finds the topics closest to the question using cosine similarity
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

    func search(_ question: String, k: Int = 5) throws -> [KnowledgeTopic] {
        load()
        guard let embedder else { throw NoModel() }
        let topics = Self.rank(chunks, query: try embedder.embedQuery(question), k: k)
        Log.ai.info("Top \(k) topics: \(topics.map(\.id).joined(separator: ", "), privacy: .public)")
        return topics
    }

    // Scores every text, then groups them by topic so each topic counts with its best text
    static func rank(_ chunks: [KnowledgeChunk], query: [Float], k: Int) -> [KnowledgeTopic] {
        let sorted = chunks.sorted { cosine(query, $0.embedding ?? []) > cosine(query, $1.embedding ?? []) }
        var order: [String] = []
        var byTopic: [String: [KnowledgeChunk]] = [:]
        for chunk in sorted {
            let topic = topic(of: chunk.id)
            if byTopic[topic] == nil { order.append(topic) }
            byTopic[topic, default: []].append(chunk)
        }
        return order.prefix(k).map { id in
            let texts = byTopic[id] ?? []
            let title = texts.first?.text.components(separatedBy: "\n").first ?? id
            return KnowledgeTopic(id: id, title: title, chunks: texts)
        }
    }

    // Ids look like "hemorragia-grave-atender", the topic is everything before the last part
    static func topic(of id: String) -> String {
        id.split(separator: "-").dropLast().joined(separator: "-")
    }

    // Vectors are already normalized so the dot product is enough
    private static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return -1 }
        return zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }
}
