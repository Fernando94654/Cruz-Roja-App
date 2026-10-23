import Foundation

protocol LessonsServicing: Sendable {
    func fetchLessons() async throws -> [Lesson]
}

struct MockLessonsService: LessonsServicing {
    var lessons: [Lesson] = []

    func fetchLessons() async throws -> [Lesson] {
        lessons
    }
}

struct LessonsAPIService: LessonsServicing {
    var client = APIClient()

    func fetchLessons() async throws -> [Lesson] {
        guard let lessons = try await client.get("lessons", as: [Lesson].self) else {
            throw APIError.invalidResponse
        }
        return lessons
    }
}
