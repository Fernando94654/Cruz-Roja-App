import Foundation

protocol LessonsServicing: Sendable {
    func fetchLessons() async throws -> [Lesson]
}

struct MockLessonsService: LessonsServicing {
    func fetchLessons() async throws -> [Lesson] {
        Lesson.samples
    }
}
