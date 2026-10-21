import Foundation

protocol EmergencyReportServicing: Sendable {
    func send(_ report: EmergencyReport, location: EmergencyLocation) async throws
}

// Accepts every report until the backend has the reports endpoint
struct MockEmergencyReportService: EmergencyReportServicing {
    func send(_ report: EmergencyReport, location: EmergencyLocation) async throws {}
}
