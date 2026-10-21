import Foundation
import Observation

@MainActor
@Observable
final class MedicalProfileViewModel {
    enum State: Equatable {
        case loading
        case empty
        case ready
        case failed(String)
    }

    private(set) var profile: MedicalProfile?
    private(set) var state: State = .loading
    // True when offline and showing the cached copy
    private(set) var isShowingCachedCopy = false
    private(set) var isSaving = false
    var errorMessage: String?

    private let service: MedicalProfileServicing
    private let cache: MedicalProfileCache
    private let userID: UUID

    init(service: MedicalProfileServicing, cache: MedicalProfileCache = MedicalProfileCache(), userID: UUID = APIConfig.demoUserID) {
        self.service = service
        self.cache = cache
        self.userID = userID
    }

    // Shows the cached copy right away, then refreshes from the API
    func load() async {
        if profile == nil {
            profile = cache.load()
            state = profile == nil ? .loading : .ready
        }

        do {
            let remote = try await service.fetchProfile(userID: userID)
            isShowingCachedCopy = false
            profile = remote
            if let remote {
                cache.save(remote)
                state = .ready
            } else {
                cache.clear()
                state = .empty
            }
        } catch {
            if Task.isCancelled { return }
            if profile != nil {
                isShowingCachedCopy = true
                state = .ready
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    // Returns true when saved so the editor can close
    @discardableResult
    func save(_ draft: MedicalProfile) async -> Bool {
        let cleaned = draft.cleaned()
        let errors = cleaned.validationErrors
        guard errors.isEmpty else {
            errorMessage = errors.joined(separator: "\n")
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let saved = try await service.saveProfile(cleaned, userID: userID)
            profile = saved
            cache.save(saved)
            isShowingCachedCopy = false
            state = .ready
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
