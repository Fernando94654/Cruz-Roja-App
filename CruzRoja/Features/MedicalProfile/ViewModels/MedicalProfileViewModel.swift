import Foundation
import Observation

// Controla la pantalla de Mi perfil
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
    private(set) var isShowingCachedCopy = false
    private(set) var isSaving = false
    var errorMessage: String?

    private let service: MedicalProfileServicing
    private let cache: MedicalProfileCache

    init(service: MedicalProfileServicing, cache: MedicalProfileCache = MedicalProfileCache()) {
        self.service = service
        self.cache = cache
    }

    // Muestra primero la copia guardada y luego la actualiza desde el API
    func load() async {
        if profile == nil {
            profile = cache.load()
            state = profile == nil ? .loading : .ready
        }

        do {
            let remote = try await service.fetchProfile()
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

    // Guarda el perfil en el API
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
            let saved = try await service.saveProfile(cleaned)
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

    // Borra el perfil de la pantalla y del teléfono (al cerrar sesión)
    func clear() {
        profile = nil
        state = .loading
        isShowingCachedCopy = false
        errorMessage = nil
        cache.clear()
    }
}
