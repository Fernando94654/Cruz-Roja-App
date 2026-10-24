import Foundation

protocol LessonProgressServicing: Sendable {
    /// Marks the lessons completed and returns every lesson the user has completed.
    func complete(_ lessonIDs: [UUID]) async throws -> Set<UUID>
    func uncomplete(_ lessonID: UUID) async throws
}

actor MockLessonProgressService: LessonProgressServicing {
    private var completed: Set<UUID> = []

    func complete(_ lessonIDs: [UUID]) async throws -> Set<UUID> {
        completed.formUnion(lessonIDs)
        return completed
    }

    func uncomplete(_ lessonID: UUID) async throws {
        completed.remove(lessonID)
    }
}

struct LessonProgressAPIService: LessonProgressServicing {
    var client = APIClient()

    func complete(_ lessonIDs: [UUID]) async throws -> Set<UUID> {
        let rows = try await client.post("lessons/completions", body: CompletionsRequest(lessonIDs: lessonIDs),
                                         as: [CompletionResponse].self)
        return Set(rows.map(\.lessonID))
    }

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
