import Foundation
import Observation

@MainActor
@Observable
final class LearnViewModel {
    private(set) var lessons: [Lesson] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    private let service: LessonsServicing

    init(service: LessonsServicing) {
        self.service = service
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try Task.checkCancellation()
            let fetched = try await service.fetchLessons()
            try Task.checkCancellation()
            lessons = fetched
            hasLoaded = true
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            lessons = []
            errorMessage = "No se pudieron cargar las lecciones. Revisa tu conexión e intenta de nuevo."
        }
    }
}
