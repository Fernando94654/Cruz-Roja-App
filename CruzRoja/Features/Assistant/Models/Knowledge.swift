import Foundation

// A first-aid text with its vector
struct KnowledgeChunk: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let topic: String
    let text: String
    let embedding: [Float]?
    let embeddingModel: String?

    enum CodingKeys: String, CodingKey {
        case id, topic, text, embedding
        case embeddingModel = "embedding_model"
    }
}

// The texts of one topic, best match first
struct KnowledgeTopic: Sendable {
    let id: String
    let title: String
    let chunks: [KnowledgeChunk]
}
