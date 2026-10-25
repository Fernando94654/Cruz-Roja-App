import Foundation

protocol LessonsServicing: Sendable {
    // Returns the lesson catalog
    func fetchLessons() async throws -> [Lesson]
}

struct MockLessonsService: LessonsServicing {
    var lessons: [Lesson] = []

    // Returns the fixed lessons for previews and tests
    func fetchLessons() async throws -> [Lesson] {
        lessons
    }
}

struct LessonsAPIService: LessonsServicing {
    var client = APIClient()

    // Loads GET /lessons; an empty body is an error, never a sample catalog
    func fetchLessons() async throws -> [Lesson] {
        guard let lessons = try await client.get("lessons", as: [Lesson].self) else {
            throw APIError.invalidResponse
        }
        return lessons
    }
}
