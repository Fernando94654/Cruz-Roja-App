import Foundation
import Observation

@MainActor
@Observable
final class EmergencyReportViewModel {
    var report: EmergencyReport {
        // A manual edit makes the AI summary stale
        didSet { if !isApplyingFill, oldValue != report { aiSummary = nil } }
    }
    private(set) var location: EmergencyLocation?
    private(set) var isFilling = false
    // Tells the user what "Llenar con IA" did
    private(set) var fillMessage: String?
    private(set) var aiSummary: String?
    private(set) var isLocating = false
    private(set) var isSending = false
    private(set) var shareURL: String?
    var errorMessage: String?

    let operatorPhone = APIConfig.operatorPhone
    let dictation: Dictating

    private let service: EmergencyReportServicing
    private let extractor: ReportExtracting
    private let locationProvider: LocationProviding
    private let hasProvidedLocation: Bool
    // Summary of the user's own medical profile, attached when reporting for themselves
    private let medicalSummary: () -> String?
    private var textBeforeDictation = ""
    @ObservationIgnored private var isApplyingFill = false

    init(
        report: EmergencyReport = EmergencyReport(),
        location: EmergencyLocation? = nil,
        shareURL: String? = nil,
        service: EmergencyReportServicing,
        extractor: ReportExtracting,
        locationProvider: LocationProviding,
        dictation: Dictating,
        medicalSummary: @escaping () -> String?
    ) {
        self.report = report
        self.location = location
        self.hasProvidedLocation = location != nil
        self.shareURL = shareURL
        self.service = service
        self.extractor = extractor
        self.locationProvider = locationProvider
        self.dictation = dictation
        self.medicalSummary = medicalSummary
    }

    var isSent: Bool { shareURL != nil }
    var summary: String { aiSummary ?? ReportSummarizer.summarize(report) }
    var smsBody: String { "EMERGENCIA Cruz Roja: \(summary) Ubicación: \(shareURL ?? "")" }

    var patientDescription: String {
        report.patientName.map { "\(report.reportingFor.label) (\($0))" } ?? report.reportingFor.label
    }

    // Starts a new report, e.g. prefilled for a family member
    func replaceReport(_ report: EmergencyReport) {
        self.report = report
        shareURL = nil
        errorMessage = nil
        fillMessage = nil
    }

    func prewarmAI() {
        extractor.prewarm()
    }

    // Fills the form from what the user typed or dictated, with the on-device model when available
    func fillFromDescription() async {
        let text = report.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isFilling else { return }
        isFilling = true
        fillMessage = nil
        defer { isFilling = false }
        do {
            let fields = try await extractor.extract(text)
            isApplyingFill = true
            report = report.merging(fields)
            isApplyingFill = false
            aiSummary = fields.summary
            fillMessage = Self.message(for: fields)
        } catch {
            fillMessage = "No se pudo llenar el reporte. Llena los campos a mano."
        }
    }

    private static func message(for fields: ExtractedFields) -> String {
        if fields.isEmpty { return "No reconocí datos en el texto. Llena los campos a mano." }
        switch fields.source {
        case .ai: return "Llenado con IA en el dispositivo. Revisa que esté correcto."
        case .rules(let reason?): return "IA no disponible (\(reason)). Se llenó con reglas básicas."
        case .rules(nil): return "Se llenó con reglas básicas. Revisa que esté correcto."
        }
    }

    func toggleDictation() async {
        if dictation.isListening {
            dictation.stop()
            await fillFromDescription()
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
        guard !hasProvidedLocation else { return }
        guard !isLocating else { return }
        isLocating = true
        defer { isLocating = false }
        guard let current = await locationProvider.current() else {
            location = nil
            return
        }
        let address = current.address ?? String(format: "%.5f, %.5f", current.coordinate.latitude, current.coordinate.longitude)
        location = EmergencyLocation(coordinate: current.coordinate, address: address, accuracyMeters: current.accuracyMeters)
    }

    // Returns true when the report was stored so the view can open the SMS composer
    func send() async -> Bool {
        guard !isSending else { return false }
        guard let location else {
            errorMessage = "No se pudo obtener la ubicación. Activa el permiso de ubicación e inténtalo de nuevo."
            return false
        }
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
