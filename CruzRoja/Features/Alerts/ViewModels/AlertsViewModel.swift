import Foundation
import Observation

// Alcance de las alertas oficiales que elige el usuario
enum OfficialAlertScope: String, CaseIterable, Identifiable {
    case myArea = "Mi zona"
    case allMexico = "Todo México"

    var id: Self { self }
}

@MainActor
@Observable
final class AlertsViewModel {
    private(set) var officialAlerts: [OfficialAlert] = []
    private(set) var reports: [CommunityReport] = []
    // Error de carga o de voto que se muestra arriba de la lista
    var errorMessage: String?
    // Error al publicar, se muestra dentro de la hoja de nuevo reporte
    private(set) var publishError: String?
    // Evita mostrar "no hay alertas" antes de que termine la primera carga
    private(set) var hasLoaded = false
    var selectedCategory: CommunityReportCategory?
    private(set) var officialScope: OfficialAlertScope = .myArea

    // Resumen con IA de lo que hay en pantalla; nil mientras no se genera
    private(set) var summary: AlertsSummary?
    private(set) var isSummarizing = false
    private var summaryRequest = 0

    private let service: AlertsServicing
    private let summarizer: AlertsSummarizing
    private let speech: SpeechSynthesizing

    // Sin resumidor ni voz se usan la IA del dispositivo y la voz del sistema; las pruebas pasan los suyos
    init(service: AlertsServicing, summarizer: AlertsSummarizing? = nil, speech: SpeechSynthesizing? = nil) {
        self.service = service
        self.summarizer = summarizer ?? FallbackAlertsSummarizer()
        self.speech = speech ?? SpeechService()
    }

    // Cambia cuando cambian las alertas o los reportes visibles; la vista lo usa para regenerar el resumen
    var summaryKey: [UUID] {
        guard hasLoaded else { return [] }
        return officialAlerts.map(\.id) + activeReports.map(\.id)
    }

    var isSpeaking: Bool { speech.isSpeaking }

    // Reportes vigentes: no han expirado y no alcanzan el limite de marcas de falso
    var activeReports: [CommunityReport] {
        reports.filter { $0.expiresAt > Date() && $0.flags < CommunityReport.flagThreshold }
    }

    // Aplica el filtro de categoria sobre los reportes vigentes; si es nil se muestran todos
    var filteredReports: [CommunityReport] {
        guard let selectedCategory else { return activeReports }
        return activeReports.filter { $0.category == selectedCategory }
    }

    // Carga alertas y reportes por separado: si una peticion falla, la otra se muestra de todos modos
    func load() async {
        errorMessage = nil
        await loadOfficialAlerts()
        do {
            reports = try await service.fetchCommunityReports()
        } catch {
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
    }

    // Cambia entre las alertas de la zona del usuario y las de todo Mexico; solo recarga las oficiales
    func setOfficialScope(_ scope: OfficialAlertScope) async {
        guard scope != officialScope else { return }
        officialScope = scope
        await loadOfficialAlerts()
    }

    private func loadOfficialAlerts() async {
        do {
            officialAlerts = officialScope == .myArea
                ? try await service.fetchOfficialAlerts()
                : try await service.fetchAllOfficialAlerts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Genera el resumen de las alertas y reportes visibles; solo se guarda el del pedido mas reciente
    func summarize() async {
        guard hasLoaded else { return }
        summaryRequest += 1
        let request = summaryRequest
        isSummarizing = true
        let snapshot = AlertsSnapshot(officialAlerts: officialAlerts, reports: activeReports, scope: officialScope)
        let result = await summarizer.summarize(snapshot)
        guard request == summaryRequest else { return }
        summary = result
        isSummarizing = false
    }

    // Lee el resumen en voz alta, o lo detiene si ya se esta leyendo
    func toggleSpeech() {
        if speech.isSpeaking {
            speech.stop()
        } else if let summary {
            speech.speak(summary.text)
        }
    }

    func stopSpeech() {
        speech.stop()
    }

    func dismissError() {
        errorMessage = nil
    }

    // Al abrir la hoja de nuevo reporte no debe aparecer el error de un intento anterior
    func startNewReport() {
        publishError = nil
    }

    func toggleConfirmation(_ report: CommunityReport) async {
        guard let current = reports.first(where: { $0.id == report.id }) else { return }
        let on = !current.confirmedByMe
        await vote(on: report.id, { $0.setConfirmed(on) }) {
            on ? try await service.confirm(reportID: report.id) : try await service.unconfirm(reportID: report.id)
        }
    }

    func toggleFalseFlag(_ report: CommunityReport) async {
        guard let current = reports.first(where: { $0.id == report.id }) else { return }
        let on = !current.flaggedByMe
        await vote(on: report.id, { $0.setFlagged(on) }) {
            on ? try await service.flag(reportID: report.id) : try await service.unflag(reportID: report.id)
        }
    }

    // Actualizacion optimista: el voto se refleja de inmediato y se reemplaza con la respuesta del servidor; si la peticion falla, se revierte
    private func vote(on id: UUID, _ change: (inout CommunityReport) -> Void,
                      send: () async throws -> CommunityReport) async {
        guard let i = reports.firstIndex(where: { $0.id == id }) else { return }
        let before = reports[i]
        change(&reports[i])
        do {
            let saved = try await send()
            if let j = reports.firstIndex(where: { $0.id == id }) { reports[j] = saved }
        } catch {
            if let j = reports.firstIndex(where: { $0.id == id }) { reports[j] = before }
            errorMessage = error.localizedDescription
        }
    }

    // Publica el reporte y lo agrega al inicio de la lista si el servidor lo acepta
    func publish(category: CommunityReportCategory, title: String) async -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        publishError = nil
        do {
            let report = try await service.publish(category: category, title: title)
            reports.insert(report, at: 0)
            return true
        } catch {
            publishError = error.localizedDescription
            return false
        }
    }
}
