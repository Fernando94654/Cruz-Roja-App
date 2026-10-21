package mx.cruzroja.enlacevital.features.emergency.data

import mx.cruzroja.enlacevital.features.emergency.model.EmergencyLocation
import mx.cruzroja.enlacevital.features.emergency.model.EmergencyReport

interface EmergencyReportService {
    suspend fun send(report: EmergencyReport, location: EmergencyLocation)
}

// Accepts every report until the backend has the reports endpoint
class MockEmergencyReportService : EmergencyReportService {
    override suspend fun send(report: EmergencyReport, location: EmergencyLocation) {}
}
