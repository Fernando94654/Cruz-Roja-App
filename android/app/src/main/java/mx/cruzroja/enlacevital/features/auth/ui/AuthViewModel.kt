package mx.cruzroja.enlacevital.features.auth.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.cruzroja.enlacevital.features.auth.data.AuthService
import mx.cruzroja.enlacevital.features.auth.data.SessionStore

data class AuthUiState(
    val email: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

class AuthViewModel(private val service: AuthService, private val session: SessionStore) : ViewModel() {
    private val _state = MutableStateFlow(AuthUiState())
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    fun setEmail(email: String) = _state.update { it.copy(email = email) }

    fun setPassword(password: String) = _state.update { it.copy(password = password) }

    fun signIn(onSignedIn: () -> Unit) {
        _state.update { it.copy(isLoading = true) }
        viewModelScope.launch {
            try {
                session.signIn(service.signIn(_state.value.email, _state.value.password))
                onSignedIn()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(errorMessage = e.message) }
            } finally {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }
}
