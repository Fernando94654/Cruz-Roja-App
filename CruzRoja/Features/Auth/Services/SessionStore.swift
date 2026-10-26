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
        // In presentation mode you start signed in as the sample user
        isSignedIn = DemoMode.offline || defaults.bool(forKey: Keys.signedIn)
        email = defaults.string(forKey: Keys.email) ?? (DemoMode.offline ? "maria@ejemplo.com" : "")
    }

    func signIn(email: String) {
        self.email = email
        isSignedIn = true
        defaults.set(email, forKey: Keys.email)
        defaults.set(true, forKey: Keys.signedIn)
    }

    func signOut() {
        AuthToken.clear()
        // The server keeps the progress; the next person on this phone shouldn't see it
        LessonProgressStore(defaults: defaults).clear()
        isSignedIn = false
        defaults.set(false, forKey: Keys.signedIn)
    }

    private enum Keys {
        static let signedIn = "session.signedIn"
        static let email = "session.email"
    }
}
