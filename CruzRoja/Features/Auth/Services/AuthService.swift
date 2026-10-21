import Foundation

protocol AuthServicing: Sendable {
    func signIn(email: String, password: String) async throws -> String
}

// Accepts any credentials until the backend has auth endpoints
struct MockAuthService: AuthServicing {
    func signIn(email: String, password: String) async throws -> String {
        try? await Task.sleep(for: .seconds(1))
        return email.isEmpty ? "usuario@correo.com" : email
    }
}
