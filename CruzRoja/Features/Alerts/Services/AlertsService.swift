import Foundation

protocol AlertsServicing: Sendable {
    func fetchOfficialAlerts() async throws -> [OfficialAlert]
    func fetchCommunityReports() async throws -> [CommunityReport]
    func confirm(reportID: UUID) async throws
    func flag(reportID: UUID) async throws
    func publish(category: CommunityReportCategory, title: String) async throws -> CommunityReport
}

actor MockAlertsService: AlertsServicing {
    // Community reports expire a few hours after being published
    static let reportLifetime: TimeInterval = 4 * 3600

    private var reports = CommunityReport.samples()

    func fetchOfficialAlerts() async throws -> [OfficialAlert] {
        OfficialAlert.samples()
    }

    func fetchCommunityReports() async throws -> [CommunityReport] {
        reports
    }

    func confirm(reportID: UUID) async throws {
        guard let i = reports.firstIndex(where: { $0.id == reportID }) else { return }
        reports[i].confirmations += 1
    }

    func flag(reportID: UUID) async throws {
        guard let i = reports.firstIndex(where: { $0.id == reportID }) else { return }
        reports[i].flags += 1
    }

    func publish(category: CommunityReportCategory, title: String) async throws -> CommunityReport {
        let report = CommunityReport(category: category, title: title, confirmations: 0,
                                     expiresAt: Date().addingTimeInterval(Self.reportLifetime))
        reports.insert(report, at: 0)
        return report
    }
}
