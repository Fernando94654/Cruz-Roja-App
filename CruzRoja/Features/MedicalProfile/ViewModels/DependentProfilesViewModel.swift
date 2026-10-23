import Foundation
import Observation

// Profiles of family members the user looks after, shown under "Familiares" in the profile tab
@MainActor
@Observable
final class DependentProfilesViewModel {
    enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    private(set) var dependents: [DependentProfile] = []
    private(set) var state: State = .loading
    // True when offline and showing the cached list
    private(set) var isShowingCachedCopy = false
    private(set) var isSaving = false
    var errorMessage: String?

    private let service: DependentProfilesServicing
    private let cache: DependentProfilesCache
    private let userID: UUID

    init(service: DependentProfilesServicing, cache: DependentProfilesCache = DependentProfilesCache(), userID: UUID = APIConfig.demoUserID) {
        self.service = service
        self.cache = cache
        self.userID = userID
    }

    var canAddMore: Bool {
        dependents.count < DependentProfile.maxDependents
    }

    func dependent(id: UUID) -> DependentProfile? {
        dependents.first { $0.id == id }
    }

    // Shows the cached list right away, then refreshes from the API
    func load() async {
        if state != .ready, let cached = cache.load() {
            dependents = cached
            state = .ready
        }

        do {
            let remote = try await service.fetchDependents(userID: userID)
            dependents = remote
            cache.save(remote)
            isShowingCachedCopy = false
            state = .ready
        } catch {
            if Task.isCancelled { return }
            if state == .ready {
                isShowingCachedCopy = true
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    // Creates a new dependent or updates an existing one; returns true when saved so the editor can close
    @discardableResult
    func save(_ draft: DependentProfile) async -> Bool {
        let cleaned = draft.cleaned()
        let errors = cleaned.validationErrors
        guard errors.isEmpty else {
            errorMessage = errors.joined(separator: "\n")
            return false
        }

        let isNew = dependent(id: cleaned.id) == nil
        if isNew && !canAddMore {
            errorMessage = "Puedes registrar hasta \(DependentProfile.maxDependents) familiares."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if isNew {
                let saved = try await service.createDependent(cleaned, userID: userID)
                dependents.append(saved)
            } else {
                let saved = try await service.updateDependent(cleaned, userID: userID)
                if let index = dependents.firstIndex(where: { $0.id == saved.id }) {
                    dependents[index] = saved
                }
            }
            cache.save(dependents)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // Returns true when deleted so the detail screen can close
    @discardableResult
    func delete(_ dependent: DependentProfile) async -> Bool {
        do {
            try await service.deleteDependent(id: dependent.id, userID: userID)
            dependents.removeAll { $0.id == dependent.id }
            cache.save(dependents)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
