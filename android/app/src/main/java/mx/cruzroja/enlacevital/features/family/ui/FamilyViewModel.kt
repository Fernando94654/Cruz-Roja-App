package mx.cruzroja.enlacevital.features.family.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.cruzroja.enlacevital.features.emergency.model.EmergencyReport
import mx.cruzroja.enlacevital.features.emergency.model.ReportingFor
import mx.cruzroja.enlacevital.features.family.data.FamilyService
import mx.cruzroja.enlacevital.features.family.model.FamilyAlert
import mx.cruzroja.enlacevital.features.family.model.FamilyMember

data class FamilyUiState(
    val members: List<FamilyMember> = emptyList(),
    val activeAlert: FamilyAlert? = null,
    val hasSentWellbeingCheck: Boolean = false,
    val errorMessage: String? = null,
)

class FamilyViewModel(private val service: FamilyService) : ViewModel() {
    private val _state = MutableStateFlow(FamilyUiState())
    val state: StateFlow<FamilyUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            try {
                val members = service.fetchMembers()
                val alert = service.fetchActiveAlert()
                _state.update { it.copy(members = members, activeAlert = alert) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(errorMessage = e.message) }
            }
        }
    }

    // "¿Estás bien?" check sent to the member with the active alert
    fun sendWellbeingCheck() {
        val alert = _state.value.activeAlert ?: return
        viewModelScope.launch {
            try {
                service.sendWellbeingCheck(alert.memberName)
                _state.update { it.copy(hasSentWellbeingCheck = true) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(errorMessage = e.message) }
            }
        }
    }

    // Report prefilled with the member's data for "Reportar por ella"
    fun reportForActiveAlert(): EmergencyReport {
        val alert = _state.value.activeAlert
        return EmergencyReport(reportingFor = ReportingFor.FAMILY_MEMBER, patientName = alert?.memberName, reason = alert?.reason.orEmpty())
    }
}
