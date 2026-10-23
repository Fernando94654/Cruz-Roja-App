import Foundation

struct SentReport: Decodable, Sendable {
    let id: String
    let shareURL: String

    enum CodingKeys: String, CodingKey {
        case id
        case shareURL = "share_url"
    }
}

protocol EmergencyReportServicing: Sendable {
    func send(_ report: EmergencyReport, location: EmergencyLocation, summary: String, medicalSummary: String?) async throws -> SentReport
}

private struct EmergencyReportRequest: Encodable {
    let reportingFor: String
    let patientName: String?
    let reason: String
    let injuredCount: Int
    let injury: String
    let place: String
    let reference: String
    let mentalState: String
    let breathing: String
    let skin: String
    let transcript: String
    let summary: String
    let medicalSummary: String?
    let latitude: Double
    let longitude: Double
    let address: String

    enum CodingKeys: String, CodingKey {
        case reportingFor = "reporting_for"
        case patientName = "patient_name"
        case reason
        case injuredCount = "injured_count"
        case injury, place, reference
        case mentalState = "mental_state"
        case breathing, skin, transcript, summary
        case medicalSummary = "medical_summary"
        case latitude, longitude, address
    }
}

// POST /emergency-reports
struct EmergencyReportAPIService: EmergencyReportServicing {
    var client = APIClient()

    func send(_ report: EmergencyReport, location: EmergencyLocation, summary: String, medicalSummary: String?) async throws -> SentReport {
        let request = EmergencyReportRequest(
            reportingFor: report.reportingFor.wireValue,
            patientName: report.patientName,
            reason: report.reason,
            injuredCount: report.injuredCount,
            injury: report.injury,
            place: report.place,
            reference: report.reference,
            mentalState: report.mentalState,
            breathing: report.breathing,
            skin: report.skin,
            transcript: report.description,
            summary: summary,
            medicalSummary: medicalSummary,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            address: location.address
        )
        return try await client.post("emergency-reports", body: request, as: SentReport.self)
    }
}

// Offline stand-in for previews and tests
struct MockEmergencyReportService: EmergencyReportServicing {
    func send(_ report: EmergencyReport, location: EmergencyLocation, summary: String, medicalSummary: String?) async throws -> SentReport {
        SentReport(id: "demo", shareURL: "http://localhost:8000/r/demo")
    }
}
