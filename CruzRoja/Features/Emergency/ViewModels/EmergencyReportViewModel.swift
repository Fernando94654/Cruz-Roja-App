import Foundation
import Observation

@MainActor
@Observable
final class EmergencyReportViewModel {
    var report: EmergencyReport
    private(set) var location: EmergencyLocation = .fallback
    private(set) var isLocating = false
    private(set) var isSending = false
    private(set) var shareURL: String?
    var errorMessage: String?

    let operatorPhone = APIConfig.operatorPhone
    let dictation: Dictating

    private let service: EmergencyReportServicing
    private let extractor: ReportExtracting
    private let locationProvider: LocationProviding
    // Summary of the user's own medical profile, attached when reporting for themselves
    private let medicalSummary: () -> String?
    private var textBeforeDictation = ""

    init(
        report: EmergencyReport = EmergencyReport(),
        shareURL: String? = nil,
        service: EmergencyReportServicing,
        extractor: ReportExtracting,
        locationProvider: LocationProviding,
        dictation: Dictating,
        medicalSummary: @escaping () -> String?
    ) {
        self.report = report
        self.shareURL = shareURL
        self.service = service
        self.extractor = extractor
        self.locationProvider = locationProvider
        self.dictation = dictation
        self.medicalSummary = medicalSummary
    }

    var isSent: Bool { shareURL != nil }
    var summary: String { ReportSummarizer.summarize(report) }
    var smsBody: String { "EMERGENCIA Cruz Roja: \(summary) Ubicación: \(shareURL ?? "")" }

    var patientDescription: String {
        report.patientName.map { "\(report.reportingFor.label) (\($0))" } ?? report.reportingFor.label
    }

    // Starts a new report, e.g. prefilled for a family member
    func replaceReport(_ report: EmergencyReport) {
        self.report = report
        shareURL = nil
        errorMessage = nil
    }

    // On-device "AI": fills the form from what the user typed or dictated
    func fillFromDescription() {
        report = report.merging(extractor.extract(report.description))
    }

    func toggleDictation() async {
        if dictation.isListening {
            dictation.stop()
            fillFromDescription()
            return
        }
        textBeforeDictation = report.description
        do {
            try await dictation.start { [weak self] text in
                guard let self else { return }
                report.description = [textBeforeDictation, text].filter { !$0.isEmpty }.joined(separator: " ")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func locate() async {
        guard !isLocating else { return }
        isLocating = true
        defer { isLocating = false }
        guard let current = await locationProvider.current() else {
            location = .fallback
            return
        }
        let address = current.address ?? String(format: "%.5f, %.5f", current.coordinate.latitude, current.coordinate.longitude)
        location = EmergencyLocation(coordinate: current.coordinate, address: address, accuracyMeters: current.accuracyMeters)
    }

    // Returns true when the report was stored so the view can open the SMS composer
    func send() async -> Bool {
        guard !isSending else { return false }
        isSending = true
        defer { isSending = false }
        do {
            let medical = report.reportingFor == .myself ? medicalSummary() : nil
            let sent = try await service.send(report, location: location, summary: summary, medicalSummary: medical)
            shareURL = sent.shareURL
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
