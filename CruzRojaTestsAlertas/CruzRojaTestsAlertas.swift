import Foundation
import Testing
@testable import CruzRoja

// Servicio que carga los reportes de ejemplo pero falla al votar, para probar que el voto se revierte
private actor FailingVoteService: AlertsServicing {
    func fetchOfficialAlerts() async throws -> [OfficialAlert] { OfficialAlert.samples() }
    func fetchCommunityReports() async throws -> [CommunityReport] { CommunityReport.samples() }
    func confirm(reportID: UUID) async throws -> CommunityReport { throw APIError.offline }
    func unconfirm(reportID: UUID) async throws -> CommunityReport { throw APIError.offline }
    func flag(reportID: UUID) async throws -> CommunityReport { throw APIError.offline }
    func unflag(reportID: UUID) async throws -> CommunityReport { throw APIError.offline }
    func publish(category: CommunityReportCategory, title: String) async throws -> CommunityReport {
        throw APIError.offline
    }
}

@MainActor
struct CruzRojaTestsAlertas {
    // Crea el ViewModel con el servicio de prueba y carga los datos de ejemplo
    private func loadedViewModel() async -> AlertsViewModel {
        let viewModel = AlertsViewModel(service: MockAlertsService())
        await viewModel.load()
        return viewModel
    }

    private func report(_ category: CommunityReportCategory, in viewModel: AlertsViewModel) -> CommunityReport? {
        viewModel.reports.first { $0.category == category }
    }

    @Test("Se cargan las alertas oficiales con su severidad y los reportes vigentes")
    func loadsAlertsAndReports() async {
        let viewModel = await loadedViewModel()
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.officialAlerts.count == 3)
        #expect(viewModel.officialAlerts.contains { $0.severity == .extreme })
        #expect(viewModel.activeReports.count == 3)
    }

    @Test("Confirmar un reporte hasta 3 votos lo marca como confirmado")
    func confirmReachesThreshold() async throws {
        let viewModel = await loadedViewModel()
        let semaforo = try #require(report(.trafficLight, in: viewModel))
        #expect(!semaforo.isConfirmed)

        await viewModel.toggleConfirmation(semaforo)
        let updated = try #require(report(.trafficLight, in: viewModel))
        #expect(updated.confirmations == 3 && updated.confirmedByMe && updated.isConfirmed)
    }

    @Test("Un usuario tiene un solo voto: marcar falso quita su confirmacion y tocar otra vez lo quita")
    func oneVotePerUser() async throws {
        let viewModel = await loadedViewModel()
        let semaforo = try #require(report(.trafficLight, in: viewModel))

        await viewModel.toggleConfirmation(semaforo)
        await viewModel.toggleFalseFlag(try #require(report(.trafficLight, in: viewModel)))
        var updated = try #require(report(.trafficLight, in: viewModel))
        #expect(!updated.confirmedByMe && updated.confirmations == 2)
        #expect(updated.flaggedByMe && updated.flags == 1)

        await viewModel.toggleFalseFlag(updated)
        updated = try #require(report(.trafficLight, in: viewModel))
        #expect(!updated.flaggedByMe && updated.flags == 0)
    }

    @Test("Un reporte con 3 marcas de falso deja de mostrarse")
    func flaggedReportIsHidden() async throws {
        let viewModel = await loadedViewModel()
        let arbol = try #require(report(.fallenTree, in: viewModel))
        #expect(arbol.flags == 2 && viewModel.activeReports.contains { $0.id == arbol.id })

        await viewModel.toggleFalseFlag(arbol)
        #expect(!viewModel.activeReports.contains { $0.id == arbol.id })
    }

    @Test("El filtro por categoria solo muestra reportes de esa categoria")
    func categoryFilter() async {
        let viewModel = await loadedViewModel()

        viewModel.selectedCategory = .flood
        #expect(!viewModel.filteredReports.isEmpty)
        #expect(viewModel.filteredReports.allSatisfy { $0.category == .flood })

        viewModel.selectedCategory = .fire
        #expect(viewModel.filteredReports.isEmpty)

        viewModel.selectedCategory = nil
        #expect(viewModel.filteredReports.count == viewModel.activeReports.count)
    }

    @Test("Publicar agrega el reporte al inicio, expira en 4 horas y no acepta titulos vacios")
    func publishReport() async throws {
        let viewModel = await loadedViewModel()

        #expect(await viewModel.publish(category: .fire, title: "  Humo en el parque  "))
        let nuevo = try #require(viewModel.reports.first)
        #expect(nuevo.category == .fire && nuevo.title == "Humo en el parque" && nuevo.isMine)
        #expect(abs(nuevo.expiresAt.timeIntervalSinceNow - 4 * 3600) < 60)

        #expect(await viewModel.publish(category: .fire, title: "   ") == false)
    }

    @Test("Si el servidor falla al votar, el voto se revierte y se muestra un error")
    func voteRevertsOnError() async throws {
        let viewModel = AlertsViewModel(service: FailingVoteService())
        await viewModel.load()
        let semaforo = try #require(report(.trafficLight, in: viewModel))

        await viewModel.toggleConfirmation(semaforo)
        let updated = try #require(report(.trafficLight, in: viewModel))
        #expect(updated.confirmations == 2 && !updated.confirmedByMe)
        #expect(viewModel.errorMessage != nil)
    }
}
