import Foundation
import Observation

@MainActor
@Observable
final class LearnViewModel {
    private(set) var lessons: [Lesson] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    let progress: LessonProgress?
    // For the lesson thumbnails' icons
    let guides: [FirstAidGuide]

    private let service: LessonsServicing

    // Progress is optional so the emergency screens can reuse the lesson list
    init(service: LessonsServicing, progress: LessonProgress? = nil, guides: [FirstAidGuide] = FirstAidGuide.bundled) {
        self.service = service
        self.progress = progress
        self.guides = guides
    }

    // Fetches the lessons, shows an error on failure and syncs progress on success
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
            // Each visit pushes progress saved offline or before signing in
            await progress?.sync()
        } catch is CancellationError {
            return
        } catch {
            lessons = []
            errorMessage = "No se pudieron cargar las lecciones. Revisa tu conexión e intenta de nuevo."
        }
    }
}
