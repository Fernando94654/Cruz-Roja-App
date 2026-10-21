import Foundation
import Observation

// Signed-in state shared by the whole app, persisted in UserDefaults
@MainActor
@Observable
final class SessionStore {
    private(set) var isSignedIn: Bool
    private(set) var email: String

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isSignedIn = defaults.bool(forKey: Keys.signedIn)
        email = defaults.string(forKey: Keys.email) ?? ""
    }

    func signIn(email: String) {
        self.email = email
        isSignedIn = true
        defaults.set(email, forKey: Keys.email)
        defaults.set(true, forKey: Keys.signedIn)
    }

    func signOut() {
        isSignedIn = false
        defaults.set(false, forKey: Keys.signedIn)
    }

    private enum Keys {
        static let signedIn = "session.signedIn"
        static let email = "session.email"
    }
}
