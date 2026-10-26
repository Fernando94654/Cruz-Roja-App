import Foundation
import Observation

/// Which lessons are completed, shared by the lesson list and the lesson screen.
/// Saved on the device first; synced with the server only while signed in.
@MainActor
@Observable
final class LessonProgress {
    private(set) var completed: Set<UUID>

    @ObservationIgnored private let service: LessonProgressServicing
    @ObservationIgnored private let store: LessonProgressStore
    @ObservationIgnored private let isSignedIn: () -> Bool
    @ObservationIgnored private var isSyncing = false

    // Starts from the progress saved on the device
    init(service: LessonProgressServicing, store: LessonProgressStore = LessonProgressStore(),
         isSignedIn: @escaping () -> Bool = { AuthToken.current != nil }) {
        self.service = service
        self.store = store
        self.isSignedIn = isSignedIn
        completed = store.completed
    }

    // Whether this lesson is marked completed
    func isCompleted(_ lesson: Lesson) -> Bool {
        completed.contains(lesson.id)
    }

    // Only lessons still in the catalog count
    func completedCount(in lessons: [Lesson]) -> Int {
        lessons.filter(isCompleted).count
    }

    // Marks or unmarks the lesson on the device, then tries to sync
    func toggle(_ lesson: Lesson) async {
        if completed.contains(lesson.id) {
            completed.remove(lesson.id)
            store.pendingRemovals.insert(lesson.id)
        } else {
            completed.insert(lesson.id)
            store.pendingRemovals.remove(lesson.id)
        }
        store.completed = completed
        await sync()
    }

    /// Sends what changed on this device, then adopts the server's list.
    /// A failure keeps the local state; the next sync tries again.
    func sync() async {
        completed = store.completed // picks up a sign-out that cleared the device copy
        guard isSignedIn(), !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            for id in store.pendingRemovals {
                try await service.uncomplete(id)
                store.pendingRemovals.remove(id)
            }
            let server = try await service.complete(Array(store.completed))
            // Keeps taps made while the request was in flight
            completed = server.union(store.completed).subtracting(store.pendingRemovals)
            store.completed = completed
        } catch {
            return
        }
    }
}
