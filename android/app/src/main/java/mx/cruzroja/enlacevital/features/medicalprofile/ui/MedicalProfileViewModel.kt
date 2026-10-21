package mx.cruzroja.enlacevital.features.medicalprofile.ui

import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.cruzroja.enlacevital.core.networking.ApiConfig
import mx.cruzroja.enlacevital.features.medicalprofile.data.MedicalProfileCache
import mx.cruzroja.enlacevital.features.medicalprofile.data.MedicalProfileService
import mx.cruzroja.enlacevital.features.medicalprofile.model.MedicalProfile

sealed interface LoadState {
    data object Loading : LoadState
    data object Empty : LoadState
    data object Ready : LoadState
    data class Failed(val message: String) : LoadState
}

data class MedicalProfileUiState(
    val profile: MedicalProfile? = null,
    val loadState: LoadState = LoadState.Loading,
    // True when offline and showing the cached copy
    val isShowingCachedCopy: Boolean = false,
    val isSaving: Boolean = false,
    val errorMessage: String? = null,
    // Contact phones stay out of the QR unless the user opts in
    val qrIncludesContacts: Boolean = false,
)

class MedicalProfileViewModel(
    private val service: MedicalProfileService,
    private val cache: MedicalProfileCache,
    private val preferences: SharedPreferences? = null,
    private val userId: String = ApiConfig.DEMO_USER_ID,
) : ViewModel() {
    private val _state = MutableStateFlow(
        MedicalProfileUiState(qrIncludesContacts = preferences?.getBoolean(QR_CONTACTS_KEY, false) ?: false),
    )
    val state: StateFlow<MedicalProfileUiState> = _state.asStateFlow()

    init {
        load()
    }

    // Shows the cached copy right away, then refreshes from the API
    fun load() {
        if (_state.value.profile == null) {
            val cached = cache.load()
            _state.update { it.copy(profile = cached, loadState = if (cached == null) LoadState.Loading else LoadState.Ready) }
        }
        viewModelScope.launch {
            try {
                val remote = service.fetchProfile(userId)
                if (remote != null) cache.save(remote) else cache.clear()
                _state.update {
                    it.copy(profile = remote, isShowingCachedCopy = false, loadState = if (remote == null) LoadState.Empty else LoadState.Ready)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update {
                    if (it.profile != null) it.copy(isShowingCachedCopy = true, loadState = LoadState.Ready)
                    else it.copy(loadState = LoadState.Failed(e.message ?: "Error desconocido"))
                }
            }
        }
    }

    // Calls onSaved only when stored so the editor can close
    fun save(draft: MedicalProfile, onSaved: () -> Unit) {
        val cleaned = draft.cleaned()
        val errors = cleaned.validationErrors
        if (errors.isNotEmpty()) {
            _state.update { it.copy(errorMessage = errors.joinToString("\n")) }
            return
        }
        _state.update { it.copy(isSaving = true) }
        viewModelScope.launch {
            try {
                val saved = service.saveProfile(cleaned, userId)
                cache.save(saved)
                _state.update { it.copy(profile = saved, isShowingCachedCopy = false, loadState = LoadState.Ready, isSaving = false) }
                onSaved()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(isSaving = false, errorMessage = e.message) }
            }
        }
    }

    fun dismissError() {
        _state.update { it.copy(errorMessage = null) }
    }

    fun setQrIncludesContacts(include: Boolean) {
        preferences?.edit()?.putBoolean(QR_CONTACTS_KEY, include)?.apply()
        _state.update { it.copy(qrIncludesContacts = include) }
    }

    private companion object {
        const val QR_CONTACTS_KEY = "qrIncludesContacts"
    }
}
