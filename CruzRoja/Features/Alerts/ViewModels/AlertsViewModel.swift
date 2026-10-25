import Foundation
import Observation

@MainActor
@Observable
final class AlertsViewModel {
    private(set) var officialAlerts: [OfficialAlert] = []
    private(set) var reports: [CommunityReport] = []
    var errorMessage: String?
    var selectedCategory: CommunityReportCategory?

    private let service: AlertsServicing

    init(service: AlertsServicing) {
        self.service = service
    }

    // Reportes vigentes: no han expirado y no alcanzan el limite de marcas de falso
    var activeReports: [CommunityReport] {
        reports.filter { $0.expiresAt > Date() && $0.flags < CommunityReport.flagThreshold }
    }

    // Aplica el filtro de categoria sobre los reportes vigentes; si es nil se muestran todos
    var filteredReports: [CommunityReport] {
        guard let selectedCategory else { return activeReports }
        return activeReports.filter { $0.category == selectedCategory }
    }

    func load() async {
        do {
            officialAlerts = try await service.fetchOfficialAlerts()
            reports = try await service.fetchCommunityReports()
        } catch {
            errorMessage = error.localizedDescription
        }
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
        do {
            let report = try await service.publish(category: category, title: title)
            reports.insert(report, at: 0)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
