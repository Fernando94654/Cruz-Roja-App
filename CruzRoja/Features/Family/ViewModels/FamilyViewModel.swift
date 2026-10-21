import Foundation
import Observation

@MainActor
@Observable
final class FamilyViewModel {
    private(set) var members: [FamilyMember] = []
    private(set) var activeAlert: FamilyAlert?
    private(set) var hasSentWellbeingCheck = false
    var errorMessage: String?

    private let service: FamilyServicing

    init(service: FamilyServicing) {
        self.service = service
    }

    func load() async {
        do {
            members = try await service.fetchMembers()
            activeAlert = try await service.fetchActiveAlert()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // "¿Estás bien?" check sent to the member with the active alert
    func sendWellbeingCheck() async {
        guard let alert = activeAlert else { return }
        do {
            try await service.sendWellbeingCheck(to: alert.memberName)
            hasSentWellbeingCheck = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Report prefilled with the member's data for "Reportar por ella"
    func reportForActiveAlert() -> EmergencyReport {
        var report = EmergencyReport()
        report.reportingFor = .familyMember
        report.patientName = activeAlert?.memberName
        report.reason = activeAlert?.reason ?? ""
        return report
    }
}
