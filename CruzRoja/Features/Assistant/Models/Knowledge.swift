import Foundation

// A first-aid text with its vector
struct KnowledgeChunk: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let text: String
    let embedding: [Float]?
    let embeddingModel: String?

    enum CodingKeys: String, CodingKey {
        case id, text, embedding
        case embeddingModel = "embedding_model"
    }
}
