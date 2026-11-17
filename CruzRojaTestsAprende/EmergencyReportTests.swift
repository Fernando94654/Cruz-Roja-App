import Foundation
import Testing
@testable import CruzRoja

// Returns fixed fields, as the on-device model or the rules would
@MainActor
private final class StubExtractor: ReportExtracting {
    var fields: ExtractedFields
    var error: Error?

    init(_ fields: ExtractedFields = ExtractedFields(), error: Error? = nil) {
        self.fields = fields
        self.error = error
    }

    func extract(_ text: String) async throws -> ExtractedFields {
        if let error { throw error }
        return fields
    }
}

// Records what the view model sends
private actor RecordingReportService: EmergencyReportServicing {
    var medicalSummaries: [String?] = []
    var summaries: [String] = []

    func send(_ report: EmergencyReport, location: EmergencyLocation, summary: String, medicalSummary: String?) async throws -> SentReport {
        medicalSummaries.append(medicalSummary)
        summaries.append(summary)
        return SentReport(id: "1", shareURL: "http://localhost:8000/r/abc")
    }
}

private struct ModelFailure: Error {}

private let monterrey = CurrentLocation(coordinate: .monterrey, address: "Av. Eugenio Garza Sada 2501", accuracyMeters: 5)

@MainActor
private func makeViewModel(extractor: ReportExtracting? = nil,
                           service: EmergencyReportServicing = RecordingReportService(),
                           location: CurrentLocation? = monterrey,
                           dictation: Dictating? = nil) -> EmergencyReportViewModel {
    EmergencyReportViewModel(
        service: service,
        extractor: extractor ?? StubExtractor(),
        locationProvider: FixedLocationProvider(location: location),
        dictation: dictation ?? SilentDictation(),
        medicalSummary: { "Sangre O+ · Alergias: Penicilina" }
    )
}

@Suite("Rule-based extraction")
struct RuleBasedExtractionTests {
    let rules = RuleBasedReportExtractor()

    @Test func fillsFieldsFromDemoDescription() {
        let fields = rules.fields(from: EmergencyReport.demoDescription)
        #expect(fields.reportingFor == .familyMember)
        #expect(fields.patientName == "Abuela")
        #expect(fields.reason == "Caída")
        #expect(fields.place == "Casa habitación")
        #expect(fields.injury == "Golpe en la cabeza")
        #expect(fields.mentalState == "Confundido")
        #expect(fields.breathing == "Normal")
        #expect(fields.skin == "Pálida")
    }

    @Test func matchesWithoutAccentsOrCase() {
        let fields = rules.fields(from: "MI PAPÁ SE DESMAYÓ EN LA CALLE Y NO RESPIRA")
        #expect(fields.patientName == "Papa")
        #expect(fields.reason == "Desmayo")
        #expect(fields.place == "Vía pública")
        #expect(fields.breathing == "No respira")
    }

    @Test(arguments: [("hay 3 heridos en el choque", 3), ("dos personas atropelladas", 2)])
    func countsInjuredPeople(text: String, count: Int) {
        #expect(rules.fields(from: text).injuredCount == count)
    }

    @Test func returnsEmptyFieldsForUnrelatedText() {
        #expect(rules.fields(from: "hola, ¿cómo estás?").isEmpty)
    }
}

@Suite("Report merging and summary")
struct ReportMergingTests {
    @Test func keepsFieldsTheExtractorDidNotDetect() {
        var report = EmergencyReport()
        report.reference = "Casa azul, portón negro"
        report.reason = "Dolor"
        let merged = report.merging(ExtractedFields(reason: "Caída", skin: "Pálida"))
        #expect(merged.reason == "Caída")
        #expect(merged.skin == "Pálida")
        #expect(merged.reference == "Casa azul, portón negro")
    }

    @Test func summarizesFilledFields() {
        var report = EmergencyReport()
        report.patientName = "Abuela"
        report.reason = "Caída"
        report.place = "Casa habitación"
        report.injury = "Golpe en la cabeza"
        report.mentalState = "Confundido"
        report.breathing = "Normal"
        report.skin = "Pálida"
        #expect(ReportSummarizer.summarize(report)
            == "Abuela: Caída en casa habitación, 1 lesionado con golpe en la cabeza; confundido, respira normal, piel pálida.")
    }
}

@MainActor
@Suite("Emergency report view model")
struct EmergencyReportViewModelTests {
    @Test func usesTheAISummaryAndSaysTheAIFilledIt() async {
        var fields = ExtractedFields(reason: "Caída", summary: "Abuela con caída en casa.")
        fields.source = .ai
        let viewModel = makeViewModel(extractor: StubExtractor(fields))
        viewModel.report.description = "Mi abuela se cayó"

        await viewModel.fillFromDescription()

        #expect(viewModel.report.reason == "Caída")
        #expect(viewModel.summary == "Abuela con caída en casa.")
        #expect(viewModel.fillMessage == "Llenado con IA en el dispositivo. Revisa que esté correcto.")
    }

    @Test func explainsWhyRulesWereUsed() async {
        var fields = ExtractedFields(reason: "Caída")
        fields.source = .rules(reason: "activa Apple Intelligence en Ajustes")
        let viewModel = makeViewModel(extractor: StubExtractor(fields))
        viewModel.report.description = "se cayó"

        await viewModel.fillFromDescription()

        #expect(viewModel.fillMessage == "IA no disponible (activa Apple Intelligence en Ajustes). Se llenó con reglas básicas.")
    }

    @Test func asksToFillByHandWhenExtractionFails() async {
        let viewModel = makeViewModel(extractor: StubExtractor(error: ModelFailure()))
        viewModel.report.description = "texto"

        await viewModel.fillFromDescription()

        #expect(viewModel.fillMessage == "No se pudo llenar el reporte. Llena los campos a mano.")
    }

    @Test func manualEditDropsTheStaleAISummary() async {
        var fields = ExtractedFields(reason: "Caída", summary: "Resumen de la IA.")
        fields.source = .ai
        let viewModel = makeViewModel(extractor: StubExtractor(fields))
        viewModel.report.description = "se cayó"
        await viewModel.fillFromDescription()

        viewModel.report.reason = "Desmayo"

        #expect(viewModel.aiSummary == nil)
        #expect(viewModel.summary.hasPrefix("Desmayo"))
    }

    @Test func doesNotSendWithoutLocation() async {
        let viewModel = makeViewModel(location: nil)
        await viewModel.locate()

        #expect(await viewModel.send() == false)
        #expect(viewModel.errorMessage?.contains("ubicación") == true)
    }

    @Test func attachesMedicalProfileOnlyWhenReportingForMyself() async {
        let service = RecordingReportService()
        let viewModel = makeViewModel(service: service)
        await viewModel.locate()

        #expect(await viewModel.send())
        viewModel.replaceReport(EmergencyReport(reportingFor: .someoneElse))
        #expect(await viewModel.send())

        #expect(await service.medicalSummaries == ["Sangre O+ · Alergias: Penicilina", nil])
        #expect(viewModel.smsBody.hasSuffix("Ubicación: http://localhost:8000/r/abc"))
    }

    @Test func fillsTheReportWhenDictationStops() async {
        let dictation = SilentDictation()
        dictation.transcript = "mi abuela se cayó en la casa"
        let viewModel = makeViewModel(extractor: RuleBasedReportExtractor(), dictation: dictation)

        await viewModel.toggleDictation()
        await viewModel.toggleDictation()

        #expect(viewModel.report.description == "mi abuela se cayó en la casa")
        #expect(viewModel.report.reason == "Caída")
        #expect(viewModel.report.patientName == "Abuela")
    }
}
