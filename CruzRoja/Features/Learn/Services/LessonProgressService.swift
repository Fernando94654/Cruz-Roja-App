import Foundation

protocol LessonProgressServicing: Sendable {
    /// Marks the lessons completed and returns every lesson the user has completed.
    func complete(_ lessonIDs: [UUID]) async throws -> Set<UUID>
    // Removes one lesson from the user's completed list
    func uncomplete(_ lessonID: UUID) async throws
}

actor MockLessonProgressService: LessonProgressServicing {
    private var completed: Set<UUID> = []

    // Keeps completions in memory for previews and tests
    func complete(_ lessonIDs: [UUID]) async throws -> Set<UUID> {
        completed.formUnion(lessonIDs)
        return completed
    }

    // Removes the lesson from the in-memory list
    func uncomplete(_ lessonID: UUID) async throws {
        completed.remove(lessonID)
    }
}

struct LessonProgressAPIService: LessonProgressServicing {
    var client = APIClient()

    // Sends POST /lessons/completions and returns the server's full list
    func complete(_ lessonIDs: [UUID]) async throws -> Set<UUID> {
        let rows = try await client.post("lessons/completions", body: CompletionsRequest(lessonIDs: lessonIDs),
                                         as: [CompletionResponse].self)
        return Set(rows.map(\.lessonID))
    }

    // Sends DELETE /lessons/{id}/completion
    func uncomplete(_ lessonID: UUID) async throws {
        try await client.delete("lessons/\(lessonID.uuidString)/completion")
    }

    private struct CompletionsRequest: Encodable {
        let lessonIDs: [UUID]
        enum CodingKeys: String, CodingKey { case lessonIDs = "lesson_ids" }
    }

    private struct CompletionResponse: Decodable {
        let lessonID: UUID
        enum CodingKeys: String, CodingKey { case lessonID = "lesson_id" }
    }
}
