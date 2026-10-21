package mx.cruzroja.enlacevital.features.auth.data

import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class Session(val isSignedIn: Boolean = false, val email: String = "")

// Signed-in state shared by the whole app, persisted in SharedPreferences
class SessionStore(private val preferences: SharedPreferences?) {
    private val _session = MutableStateFlow(
        Session(
            isSignedIn = preferences?.getBoolean(SIGNED_IN_KEY, false) ?: false,
            email = preferences?.getString(EMAIL_KEY, "") ?: "",
        ),
    )
    val session: StateFlow<Session> = _session.asStateFlow()

    fun signIn(email: String) {
        preferences?.edit()?.putString(EMAIL_KEY, email)?.putBoolean(SIGNED_IN_KEY, true)?.apply()
        _session.value = Session(isSignedIn = true, email = email)
    }

    fun signOut() {
        preferences?.edit()?.putBoolean(SIGNED_IN_KEY, false)?.apply()
        _session.value = _session.value.copy(isSignedIn = false)
    }

    private companion object {
        const val SIGNED_IN_KEY = "session.signedIn"
        const val EMAIL_KEY = "session.email"
    }
}
