import Foundation
import Observation

@MainActor
@Observable
final class LearnViewModel {
    private(set) var lessons: [Lesson] = []
    private(set) var errorMessage: String?

    private let service: LessonsServicing

    init(service: LessonsServicing) {
        self.service = service
    }

    func load() async {
        do {
            lessons = try await service.fetchLessons()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
