package mx.cruzroja.enlacevital.features.alerts.data

import mx.cruzroja.enlacevital.features.alerts.model.CommunityReport
import mx.cruzroja.enlacevital.features.alerts.model.CommunityReportCategory
import mx.cruzroja.enlacevital.features.alerts.model.OfficialAlert
import mx.cruzroja.enlacevital.features.alerts.model.sampleCommunityReports
import mx.cruzroja.enlacevital.features.alerts.model.sampleOfficialAlerts
import java.time.Duration
import java.time.Instant

interface AlertsService {
    suspend fun fetchOfficialAlerts(): List<OfficialAlert>
    suspend fun fetchCommunityReports(): List<CommunityReport>
    suspend fun confirm(reportId: String)
    suspend fun publish(category: CommunityReportCategory, title: String): CommunityReport
}

class MockAlertsService : AlertsService {
    private val reports = sampleCommunityReports().toMutableList()

    override suspend fun fetchOfficialAlerts() = sampleOfficialAlerts()

    override suspend fun fetchCommunityReports() = reports.toList()

    override suspend fun confirm(reportId: String) {
        val i = reports.indexOfFirst { it.id == reportId }
        if (i >= 0) reports[i] = reports[i].copy(confirmations = reports[i].confirmations + 1)
    }

    override suspend fun publish(category: CommunityReportCategory, title: String): CommunityReport {
        val report = CommunityReport(category, title, 0, Instant.now().plus(REPORT_LIFETIME))
        reports.add(0, report)
        return report
    }

    private companion object {
        // Community reports expire a few hours after being published
        val REPORT_LIFETIME: Duration = Duration.ofHours(4)
    }
}
