import Foundation

protocol KnowledgeServicing: Sendable {
    func fetchKnowledge() async throws -> [KnowledgeChunk]
}

struct KnowledgeAPIService: KnowledgeServicing {
    var client = APIClient()

    func fetchKnowledge() async throws -> [KnowledgeChunk] {
        guard let chunks = try await client.get("knowledge", as: [KnowledgeChunk].self) else {
            throw APIError.invalidResponse
        }
        return chunks
    }
}

// Returns nothing so the saved copy is used
struct MockKnowledgeService: KnowledgeServicing {
    func fetchKnowledge() async throws -> [KnowledgeChunk] { [] }
}
