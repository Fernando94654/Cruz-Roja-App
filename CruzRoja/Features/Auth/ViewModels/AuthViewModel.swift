import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    private(set) var isLoading = false
    var errorMessage: String?

    private let service: AuthServicing
    private let session: SessionStore

    init(service: AuthServicing, session: SessionStore) {
        self.service = service
        self.session = session
    }

    // Returns true when signed in so the view can dismiss itself
    func signIn() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let signedInEmail = try await service.signIn(email: email, password: password)
            session.signIn(email: signedInEmail)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
