package mx.cruzroja.enlacevital.features.emergency.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.cruzroja.enlacevital.features.emergency.data.EmergencyReportService
import mx.cruzroja.enlacevital.features.emergency.model.EmergencyLocation
import mx.cruzroja.enlacevital.features.emergency.model.EmergencyReport

data class EmergencyReportUiState(
    val report: EmergencyReport = EmergencyReport(),
    val location: EmergencyLocation = EmergencyLocation.CURRENT,
    val isListening: Boolean = false,
    val isSending: Boolean = false,
    val isSent: Boolean = false,
    val errorMessage: String? = null,
) {
    val patientDescription: String
        get() = report.patientName?.let { "${report.reportingFor.label} ($it)" } ?: report.reportingFor.label
}

class EmergencyReportViewModel(
    private val service: EmergencyReportService,
    report: EmergencyReport = EmergencyReport(),
    isSent: Boolean = false,
) : ViewModel() {
    private val _state = MutableStateFlow(EmergencyReportUiState(report = report, isSent = isSent))
    val state: StateFlow<EmergencyReportUiState> = _state.asStateFlow()

    fun updateReport(transform: (EmergencyReport) -> EmergencyReport) {
        _state.update { it.copy(report = transform(it.report)) }
    }

    // Starts a new report, e.g. prefilled for a family member
    fun replaceReport(report: EmergencyReport) {
        _state.update { EmergencyReportUiState(report = report, location = it.location) }
    }

    fun dictate() {
        _state.update { it.copy(isListening = true) }
        viewModelScope.launch {
            delay(1500)
            _state.update { it.copy(report = it.report.withDictationSample(), isListening = false) }
        }
    }

    fun send() {
        _state.update { it.copy(isSending = true) }
        viewModelScope.launch {
            try {
                service.send(_state.value.report, _state.value.location)
                _state.update { it.copy(isSent = true) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(errorMessage = e.message) }
            } finally {
                _state.update { it.copy(isSending = false) }
            }
        }
    }
}
