import Foundation

// Completed lessons saved on the device, so progress works signed out and survives being offline
struct LessonProgressStore {
    var defaults: UserDefaults = .standard

    // Lessons marked completed on this device
    var completed: Set<UUID> {
        get { ids(forKey: Keys.completed) }
        nonmutating set { save(newValue, forKey: Keys.completed) }
    }

    // Undone on this device but maybe still completed on the server; sent on the next sync
    var pendingRemovals: Set<UUID> {
        get { ids(forKey: Keys.pendingRemovals) }
        nonmutating set { save(newValue, forKey: Keys.pendingRemovals) }
    }

    // Forgets all saved progress; called on sign-out
    func clear() {
        defaults.removeObject(forKey: Keys.completed)
        defaults.removeObject(forKey: Keys.pendingRemovals)
    }

    // Reads a set of UUIDs saved as strings
    private func ids(forKey key: String) -> Set<UUID> {
        Set((defaults.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:)))
    }

    // Writes a set of UUIDs as strings
    private func save(_ ids: Set<UUID>, forKey key: String) {
        defaults.set(ids.map(\.uuidString), forKey: key)
    }

    private enum Keys {
        static let completed = "lessons.completed"
        static let pendingRemovals = "lessons.pendingRemovals"
    }
}
