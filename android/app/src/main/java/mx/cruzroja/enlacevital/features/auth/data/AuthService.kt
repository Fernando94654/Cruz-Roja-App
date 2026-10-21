package mx.cruzroja.enlacevital.features.auth.data

import kotlinx.coroutines.delay

interface AuthService {
    suspend fun signIn(email: String, password: String): String
}

// Accepts any credentials until the backend has auth endpoints
class MockAuthService : AuthService {
    override suspend fun signIn(email: String, password: String): String {
        delay(1000)
        return email.ifBlank { "usuario@correo.com" }
    }
}
