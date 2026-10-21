import Foundation
import Observation

@MainActor
@Observable
final class AlertsViewModel {
    private(set) var officialAlerts: [OfficialAlert] = []
    private(set) var reports: [CommunityReport] = []
    var errorMessage: String?

    private let service: AlertsServicing

    init(service: AlertsServicing) {
        self.service = service
    }

    var activeReports: [CommunityReport] {
        reports.filter { $0.expiresAt > Date() }
    }

    func load() async {
        do {
            officialAlerts = try await service.fetchOfficialAlerts()
            reports = try await service.fetchCommunityReports()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Optimistic: counts the confirmation right away and reverts if the request fails
    func confirm(_ report: CommunityReport) async {
        guard let i = reports.firstIndex(where: { $0.id == report.id }), !reports[i].confirmedByMe else { return }
        reports[i].confirmations += 1
        reports[i].confirmedByMe = true
        do {
            try await service.confirm(reportID: report.id)
        } catch {
            if let j = reports.firstIndex(where: { $0.id == report.id }) {
                reports[j].confirmations -= 1
                reports[j].confirmedByMe = false
            }
            errorMessage = error.localizedDescription
        }
    }

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
