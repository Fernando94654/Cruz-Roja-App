import Foundation
import Observation

@MainActor
@Observable
final class EmergencyReportViewModel {
    var report: EmergencyReport
    let location: EmergencyLocation
    private(set) var isListening = false
    private(set) var isSending = false
    private(set) var isSent: Bool
    var errorMessage: String?

    private let service: EmergencyReportServicing

    init(report: EmergencyReport = EmergencyReport(), location: EmergencyLocation = .current, isSent: Bool = false, service: EmergencyReportServicing) {
        self.report = report
        self.location = location
        self.isSent = isSent
        self.service = service
    }

    var patientDescription: String {
        report.patientName.map { "\(report.reportingFor.label) (\($0))" } ?? report.reportingFor.label
    }

    func dictate() async {
        isListening = true
        try? await Task.sleep(for: .seconds(1.5))
        report.applyDictationSample()
        isListening = false
    }

    func send() async {
        isSending = true
        defer { isSending = false }
        do {
            try await service.send(report, location: location)
            isSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
