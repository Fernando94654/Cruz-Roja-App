import Foundation

protocol AuthServicing: Sendable {
    func signIn(email: String, password: String) async throws -> String
}

// POST /auth/login. The token is saved so APIClient sends it on every request
struct AuthAPIService: AuthServicing {
    var client = APIClient()

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }

    private struct LoginResponse: Decodable {
        let accessToken: String
        let email: String

        enum CodingKeys: String, CodingKey {
            case email
            case accessToken = "access_token"
        }
    }

    func signIn(email: String, password: String) async throws -> String {
        let response = try await client.post("auth/login", body: Credentials(email: email, password: password),
                                              as: LoginResponse.self)
        AuthToken.save(response.accessToken)
        return response.email
    }
}

// Accepts any credentials until the backend has auth endpoints
struct MockAuthService: AuthServicing {
    func signIn(email: String, password: String) async throws -> String {
        try? await Task.sleep(for: .seconds(1))
        return email.isEmpty ? "usuario@correo.com" : email
    }
}
