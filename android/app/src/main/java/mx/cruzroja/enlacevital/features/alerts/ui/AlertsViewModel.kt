package mx.cruzroja.enlacevital.features.alerts.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.cruzroja.enlacevital.features.alerts.data.AlertsService
import mx.cruzroja.enlacevital.features.alerts.model.CommunityReport
import mx.cruzroja.enlacevital.features.alerts.model.CommunityReportCategory
import mx.cruzroja.enlacevital.features.alerts.model.OfficialAlert
import java.time.Instant

data class AlertsUiState(
    val officialAlerts: List<OfficialAlert> = emptyList(),
    val reports: List<CommunityReport> = emptyList(),
    val errorMessage: String? = null,
) {
    val activeReports: List<CommunityReport> get() = reports.filter { it.expiresAt.isAfter(Instant.now()) }
}

class AlertsViewModel(private val service: AlertsService) : ViewModel() {
    private val _state = MutableStateFlow(AlertsUiState())
    val state: StateFlow<AlertsUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            try {
                val alerts = service.fetchOfficialAlerts()
                val reports = service.fetchCommunityReports()
                _state.update { it.copy(officialAlerts = alerts, reports = reports) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(errorMessage = e.message) }
            }
        }
    }

    // Optimistic: counts the confirmation right away and reverts if the request fails
    fun confirm(report: CommunityReport) {
        val current = _state.value.reports.firstOrNull { it.id == report.id } ?: return
        if (current.confirmedByMe) return
        setConfirmed(report.id, confirmed = true)
        viewModelScope.launch {
            try {
                service.confirm(report.id)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                setConfirmed(report.id, confirmed = false)
                _state.update { it.copy(errorMessage = e.message) }
            }
        }
    }

    fun publish(category: CommunityReportCategory, title: String, onPublished: () -> Unit) {
        val trimmed = title.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            try {
                val report = service.publish(category, trimmed)
                _state.update { it.copy(reports = listOf(report) + it.reports) }
                onPublished()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(errorMessage = e.message) }
            }
        }
    }

    private fun setConfirmed(id: String, confirmed: Boolean) {
        _state.update { state ->
            state.copy(reports = state.reports.map {
                if (it.id != id) it
                else it.copy(confirmedByMe = confirmed, confirmations = it.confirmations + if (confirmed) 1 else -1)
            })
        }
    }
}
