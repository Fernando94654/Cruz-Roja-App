import Foundation
import SwiftUI
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

// Servicio que agrega a los reportes de ejemplo uno que ya expiro, para probar que deja de mostrarse
private actor ExpiredReportService: AlertsServicing {
    static let expired = CommunityReport(category: .fire, title: "Humo en el parque",
                                         confirmations: 1, expiresAt: Date().addingTimeInterval(-60))
    func fetchOfficialAlerts() async throws -> [OfficialAlert] { OfficialAlert.samples() }
    func fetchCommunityReports() async throws -> [CommunityReport] { CommunityReport.samples() + [Self.expired] }
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

    @Test("Un reporte que ya expiro deja de mostrarse")
    func expiredReportIsHidden() async {
        let viewModel = AlertsViewModel(service: ExpiredReportService())
        await viewModel.load()
        #expect(viewModel.reports.contains { $0.id == ExpiredReportService.expired.id })
        #expect(!viewModel.activeReports.contains { $0.id == ExpiredReportService.expired.id })
        #expect(viewModel.activeReports.count == 3)
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

// Servicio en el que fallan las alertas oficiales pero los reportes cargan bien
private actor FailingOfficialService: AlertsServicing {
    func fetchOfficialAlerts() async throws -> [OfficialAlert] { throw APIError.offline }
    func fetchCommunityReports() async throws -> [CommunityReport] { CommunityReport.samples() }
    func confirm(reportID: UUID) async throws -> CommunityReport { throw APIError.offline }
    func unconfirm(reportID: UUID) async throws -> CommunityReport { throw APIError.offline }
    func flag(reportID: UUID) async throws -> CommunityReport { throw APIError.offline }
    func unflag(reportID: UUID) async throws -> CommunityReport { throw APIError.offline }
    func publish(category: CommunityReportCategory, title: String) async throws -> CommunityReport {
        throw APIError.offline
    }
}

// Ubicacion de prueba que cuenta cuantas veces se le pidio
@MainActor
private final class CountingLocationProvider: LocationProviding {
    var location: CurrentLocation?
    private(set) var requests = 0

    init(location: CurrentLocation?) {
        self.location = location
    }

    func current() async -> CurrentLocation? {
        requests += 1
        return location
    }
}

// Pruebas de los errores en pantalla y de la ubicacion que se usa para filtrar por zona
@MainActor
struct CruzRojaTestsAlertasZona {
    private let monterrey = CurrentLocation(coordinate: Coordinate(latitude: 25.6516, longitude: -100.2895),
                                            address: nil, accuracyMeters: 10)

    @Test("Si fallan las alertas oficiales, los reportes se muestran y aparece el error")
    func officialFailureStillLoadsReports() async {
        let viewModel = AlertsViewModel(service: FailingOfficialService())
        await viewModel.load()
        #expect(viewModel.officialAlerts.isEmpty)
        #expect(viewModel.reports.count == CommunityReport.samples().count)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.hasLoaded)
    }

    @Test("El aviso de error se puede cerrar y se borra al volver a cargar")
    func errorCanBeDismissed() async {
        let viewModel = AlertsViewModel(service: FailingOfficialService())
        await viewModel.load()
        viewModel.dismissError()
        #expect(viewModel.errorMessage == nil)

        let ok = AlertsViewModel(service: MockAlertsService())
        ok.errorMessage = "Error anterior"
        await ok.load()
        #expect(ok.errorMessage == nil)
    }

    @Test("Un error al publicar se muestra en la hoja del reporte, no arriba de la lista")
    func publishErrorStaysInSheet() async {
        let viewModel = AlertsViewModel(service: FailingVoteService())
        await viewModel.load()
        #expect(await viewModel.publish(category: .fire, title: "Humo") == false)
        #expect(viewModel.publishError != nil)
        #expect(viewModel.errorMessage == nil)
        viewModel.startNewReport()
        #expect(viewModel.publishError == nil)
    }

    @Test("La ubicacion se pide una sola vez para cargar alertas y reportes")
    func locationIsRequestedOnce() async {
        let provider = CountingLocationProvider(location: monterrey)
        let recent = RecentLocation()
        let first = await recent.coordinate(from: provider)
        let second = await recent.coordinate(from: provider)
        #expect(first == monterrey.coordinate && second == monterrey.coordinate)
        #expect(provider.requests == 1)
    }

    @Test("Sin permiso de ubicacion no se guarda nada y se vuelve a intentar")
    func missingLocationIsNotCached() async {
        let provider = CountingLocationProvider(location: nil)
        let recent = RecentLocation()
        #expect(await recent.coordinate(from: provider) == nil)
        provider.location = monterrey
        #expect(await recent.coordinate(from: provider) == monterrey.coordinate)
        #expect(provider.requests == 2)
    }

    @Test("Sin permiso de ubicacion no se publica el reporte y se pide activar la ubicacion")
    func publishWithoutLocationShowsMessage() async {
        let service = AlertsAPIService(locationProvider: CountingLocationProvider(location: nil))
        let viewModel = AlertsViewModel(service: service)
        #expect(await viewModel.publish(category: .fire, title: "Humo en el parque") == false)
        #expect(viewModel.publishError == "Activa tu ubicación para publicar un reporte.")
        #expect(viewModel.reports.isEmpty)
    }

    @Test("Cada severidad tiene su nombre y su color")
    func severityColors() {
        #expect(AlertSeverity.info.label == "Informativa" && AlertSeverity.info.color == .blue)
        #expect(AlertSeverity.moderate.label == "Precaución" && AlertSeverity.moderate.color == .yellow)
        #expect(AlertSeverity.high.label == "Alerta" && AlertSeverity.high.color == .orange)
        #expect(AlertSeverity.extreme.label == "Peligro" && AlertSeverity.extreme.color == .red)
    }
}

// Servicio que regresa una alerta en la zona del usuario y dos en todo Mexico
private actor ScopedOfficialService: AlertsServicing {
    static let local = OfficialAlert.samples()[0]
    static let national = Array(OfficialAlert.samples().prefix(2))
    func fetchOfficialAlerts() async throws -> [OfficialAlert] { [Self.local] }
    func fetchAllOfficialAlerts() async throws -> [OfficialAlert] { Self.national }
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
struct CruzRojaTestsAlertasAlcance {
    @Test("Por defecto se muestran las alertas de la zona y se puede cambiar a todo Mexico")
    func switchesBetweenAreaAndAllMexico() async {
        let viewModel = AlertsViewModel(service: ScopedOfficialService())
        await viewModel.load()
        #expect(viewModel.officialScope == .myArea)
        #expect(viewModel.officialAlerts.map(\.id) == [ScopedOfficialService.local.id])

        await viewModel.setOfficialScope(.allMexico)
        #expect(viewModel.officialAlerts.map(\.id) == ScopedOfficialService.national.map(\.id))

        // Al recargar se respeta la opcion elegida
        await viewModel.load()
        #expect(viewModel.officialAlerts.count == ScopedOfficialService.national.count)

        await viewModel.setOfficialScope(.myArea)
        #expect(viewModel.officialAlerts.map(\.id) == [ScopedOfficialService.local.id])
    }
}

// Resumidor de prueba que regresa un texto fijo y cuenta cuantas veces se le pidio
@MainActor
private final class FixedSummarizer: AlertsSummarizing {
    private(set) var snapshots: [AlertsSnapshot] = []

    func summarize(_ snapshot: AlertsSnapshot) async -> AlertsSummary {
        snapshots.append(snapshot)
        return AlertsSummary(text: "Resumen de prueba", source: .ai)
    }
}

@MainActor
struct CruzRojaTestsAlertasResumen {
    private func snapshot(_ alerts: [OfficialAlert], _ reports: [CommunityReport],
                          scope: OfficialAlertScope = .myArea) -> AlertsSnapshot {
        AlertsSnapshot(officialAlerts: alerts, reports: reports, scope: scope)
    }

    @Test("El resumen usa las alertas y reportes visibles y se puede escuchar")
    func summaryUsesVisibleDataAndSpeaks() async throws {
        let summarizer = FixedSummarizer()
        let speech = SilentSpeech()
        let viewModel = AlertsViewModel(service: MockAlertsService(), summarizer: summarizer, speech: speech)

        await viewModel.summarize()
        #expect(viewModel.summary == nil)  // antes de cargar no se resume nada

        await viewModel.load()
        await viewModel.summarize()
        #expect(viewModel.summary == AlertsSummary(text: "Resumen de prueba", source: .ai))
        #expect(!viewModel.isSummarizing)
        let used = try #require(summarizer.snapshots.last)
        #expect(used.officialAlerts.count == viewModel.officialAlerts.count)
        #expect(used.reports.count == viewModel.activeReports.count)

        viewModel.toggleSpeech()
        #expect(speech.spoken == ["Resumen de prueba"])
    }

    @Test("Sin alertas ni reportes, el resumen dice que todo esta tranquilo")
    func rulesWhenNothingIsHappening() {
        let text = RuleBasedAlertsSummarizer.text(for: snapshot([], []))
        #expect(text == "No hay alertas oficiales en tu zona. Ningún vecino ha reportado algo cerca. Mantente atento a nuevas alertas.")
        #expect(RuleBasedAlertsSummarizer.text(for: snapshot([], [], scope: .allMexico)).hasPrefix("No hay alertas oficiales en México."))
    }

    @Test("Las reglas mencionan la alerta mas grave, cuentan los reportes y dan una recomendacion")
    func rulesMentionWorstAlertAndReports() {
        let alerts = [
            OfficialAlert(source: "SMN", title: "Aviso de Frente Frío", areaName: "NL", issuedAt: Date(), severity: .moderate),
            OfficialAlert(source: "SMN", title: "Aviso de lluvias.", areaName: "NL", issuedAt: Date(), severity: .extreme),
        ]
        let later = Date().addingTimeInterval(3600)
        let reports = [
            CommunityReport(category: .flood, title: "Calle inundada", confirmations: 3, expiresAt: later),
            CommunityReport(category: .flood, title: "Paso a desnivel", confirmations: 0, expiresAt: later),
            CommunityReport(category: .trafficLight, title: "Semáforo apagado", confirmations: 0, expiresAt: later),
        ]
        let text = RuleBasedAlertsSummarizer.text(for: snapshot(alerts, reports))
        #expect(text == "Hay 2 alertas oficiales en tu zona; la más importante: Aviso de lluvias, nivel peligro. "
                + "Los vecinos reportan: inundación (2) y semáforo (1), 1 ya confirmado. "
                + "Evita cruzar calles y arroyos inundados.")
    }

    @Test("Sin alertas oficiales, la recomendacion sale del reporte mas comun")
    func rulesTipFromReports() {
        let later = Date().addingTimeInterval(3600)
        let reports = [CommunityReport(category: .fire, title: "Humo", confirmations: 0, expiresAt: later)]
        #expect(RuleBasedAlertsSummarizer.text(for: snapshot([], reports)).hasSuffix("Aléjate del humo y llama al 911 si ves fuego."))
    }
}
