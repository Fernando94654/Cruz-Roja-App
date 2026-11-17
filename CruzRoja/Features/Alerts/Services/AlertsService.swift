import Foundation

// Operaciones que debe implementar cualquier servicio de alertas, ya sea la API o el de prueba
protocol AlertsServicing: Sendable {
    func fetchOfficialAlerts() async throws -> [OfficialAlert]
    func fetchCommunityReports() async throws -> [CommunityReport]
    func confirm(reportID: UUID) async throws -> CommunityReport
    func unconfirm(reportID: UUID) async throws -> CommunityReport
    func flag(reportID: UUID) async throws -> CommunityReport
    func unflag(reportID: UUID) async throws -> CommunityReport
    func publish(category: CommunityReportCategory, title: String) async throws -> CommunityReport
    // Alertas oficiales de todo Mexico, sin filtrar por la zona del usuario
    func fetchAllOfficialAlerts() async throws -> [OfficialAlert]
}

// Los servicios que no distinguen zona (pruebas, demo) regresan las mismas alertas en ambos casos
extension AlertsServicing {
    func fetchAllOfficialAlerts() async throws -> [OfficialAlert] {
        try await fetchOfficialAlerts()
    }
}

// Implementacion que consume la API /alerts; el usuario se identifica mediante el token de sesion
struct AlertsAPIService: AlertsServicing {
    var client = APIClient()
    let locationProvider: any LocationProviding & Sendable
    private let recentLocation = RecentLocation()

    init(client: APIClient = APIClient(), locationProvider: any LocationProviding & Sendable) {
        self.client = client
        self.locationProvider = locationProvider
    }

    enum PublishError: LocalizedError {
        case noLocation

        var errorDescription: String? {
            "Activa tu ubicación para publicar un reporte."
        }
    }

    // Estructuras para decodificar el JSON del servidor y convertirlo a los modelos de la app
    private struct OfficialAlertDTO: Decodable {
        let id: UUID
        let source: String
        let title: String
        let description: String?
        let areaName: String?
        let severity: String
        let startsAt: Date

        enum CodingKeys: String, CodingKey {
            case id, source, title, description, severity
            case areaName = "area_name"
            case startsAt = "starts_at"
        }

        var alert: OfficialAlert {
            OfficialAlert(id: id, source: source, title: title, message: description,
                          areaName: areaName ?? "", issuedAt: startsAt,
                          severity: AlertSeverity(rawValue: severity) ?? .info)
        }
    }

    private struct ReportDTO: Decodable {
        let id: UUID
        let type: String
        let title: String
        let confirmations: Int
        let confirmedByMe: Bool
        let flags: Int
        let flaggedByMe: Bool
        let isMine: Bool
        let expiresAt: Date

        enum CodingKeys: String, CodingKey {
            case id, type, title, confirmations, flags
            case confirmedByMe = "confirmed_by_me"
            case flaggedByMe = "flagged_by_me"
            case isMine = "is_mine"
            case expiresAt = "expires_at"
        }

        var report: CommunityReport {
            CommunityReport(id: id, category: CommunityReportCategory(rawValue: type) ?? .other, title: title,
                            confirmations: confirmations, confirmedByMe: confirmedByMe, expiresAt: expiresAt,
                            flags: flags, flaggedByMe: flaggedByMe, isMine: isMine)
        }
    }

    private struct ReportBody: Encodable {
        let type: String
        let title: String
        let latitude: Double
        let longitude: Double
    }

    // Con ubicacion solo se piden las alertas de la zona del usuario; sin ella se muestran todas
    func fetchOfficialAlerts() async throws -> [OfficialAlert] {
        let alerts = try await client.get(await nearRoute("official"), as: [OfficialAlertDTO].self) ?? []
        return alerts.map(\.alert)
    }

    func fetchAllOfficialAlerts() async throws -> [OfficialAlert] {
        let alerts = try await client.get(path("official"), as: [OfficialAlertDTO].self) ?? []
        return alerts.map(\.alert)
    }

    // Con ubicacion solo se piden los reportes cercanos; sin ella se muestran todos
    func fetchCommunityReports() async throws -> [CommunityReport] {
        let reports = try await client.get(await nearRoute("reports"), as: [ReportDTO].self) ?? []
        return reports.map(\.report)
    }

    func confirm(reportID: UUID) async throws -> CommunityReport {
        try await client.post(path("reports/\(id(reportID))/confirm"), as: ReportDTO.self).report
    }

    func unconfirm(reportID: UUID) async throws -> CommunityReport {
        try await client.delete(path("reports/\(id(reportID))/confirm"), as: ReportDTO.self).report
    }

    func flag(reportID: UUID) async throws -> CommunityReport {
        try await client.post(path("reports/\(id(reportID))/flag"), as: ReportDTO.self).report
    }

    func unflag(reportID: UUID) async throws -> CommunityReport {
        try await client.delete(path("reports/\(id(reportID))/flag"), as: ReportDTO.self).report
    }

    // Se obtiene la ubicacion actual antes de enviar el reporte; sin ubicacion no se puede publicar
    func publish(category: CommunityReportCategory, title: String) async throws -> CommunityReport {
        guard let coordinate = await locationProvider.current()?.coordinate else { throw PublishError.noLocation }
        let body = ReportBody(type: category.rawValue, title: title,
                              latitude: coordinate.latitude, longitude: coordinate.longitude)
        return try await client.post(path("reports"), body: body, as: ReportDTO.self).report
    }

    private func path(_ rest: String) -> String {
        "alerts/\(rest)"
    }

    // Agrega la ubicacion a la ruta, por ejemplo alerts/official/near/25.65/-100.28
    private func nearRoute(_ rest: String) async -> String {
        guard let coordinate = await recentLocation.coordinate(from: locationProvider) else { return path(rest) }
        return path("\(rest)/near/\(coordinate.latitude)/\(coordinate.longitude)")
    }

    private func id(_ uuid: UUID) -> String {
        uuid.uuidString.lowercased()
    }
}

// Guarda la ultima ubicacion un minuto, asi al cargar alertas y reportes se pide una sola vez
// (CoreLocationService regresa nil si se le pide otra ubicacion mientras busca la primera)
actor RecentLocation {
    static let maxAge: TimeInterval = 60
    private var last: (coordinate: Coordinate, date: Date)?

    func coordinate(from provider: any LocationProviding & Sendable) async -> Coordinate? {
        if let last, Date().timeIntervalSince(last.date) < Self.maxAge { return last.coordinate }
        guard let coordinate = await provider.current()?.coordinate else { return nil }
        last = (coordinate, Date())
        return coordinate
    }
}

// Servicio con datos locales para previews y modo demo, no necesita el servidor
actor MockAlertsService: AlertsServicing {
    // Tiempo de vida de un reporte antes de expirar
    static let reportLifetime: TimeInterval = 4 * 3600

    private var reports = CommunityReport.samples()

    func fetchOfficialAlerts() async throws -> [OfficialAlert] {
        OfficialAlert.samples()
    }

    func fetchCommunityReports() async throws -> [CommunityReport] {
        reports
    }

    func confirm(reportID: UUID) async throws -> CommunityReport {
        try vote(reportID) { $0.setConfirmed(true) }
    }

    func unconfirm(reportID: UUID) async throws -> CommunityReport {
        try vote(reportID) { $0.setConfirmed(false) }
    }

    func flag(reportID: UUID) async throws -> CommunityReport {
        try vote(reportID) { $0.setFlagged(true) }
    }

    func unflag(reportID: UUID) async throws -> CommunityReport {
        try vote(reportID) { $0.setFlagged(false) }
    }

    private func vote(_ reportID: UUID, _ change: (inout CommunityReport) -> Void) throws -> CommunityReport {
        guard let i = reports.firstIndex(where: { $0.id == reportID }) else {
            throw APIError.server(status: 404, message: "El reporte ya no está vigente")
        }
        change(&reports[i])
        return reports[i]
    }

    func publish(category: CommunityReportCategory, title: String) async throws -> CommunityReport {
        let report = CommunityReport(category: category, title: title, confirmations: 0,
                                     expiresAt: Date().addingTimeInterval(Self.reportLifetime), isMine: true)
        reports.insert(report, at: 0)
        return report
    }
}
