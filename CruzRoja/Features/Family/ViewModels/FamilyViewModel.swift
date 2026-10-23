import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class FamilyViewModel {
    private(set) var family = Family()
    private(set) var hasLoaded = false
    // True while waiting for the server, buttons are disabled so nothing is sent twice
    private(set) var isBusy = false
    private(set) var loadError: String?
    // The server didn't accept the session (no token or it expired)
    private(set) var needsSignIn = false
    var errorMessage: String?
    // Short confirmation shown after an action, the view hides it after a few seconds
    var notice: String?

    private(set) var myLocation: Coordinate?

    private let service: FamilyServicing
    private let locationProvider: LocationProviding

    init(service: FamilyServicing, locationProvider: LocationProviding) {
        self.service = service
        self.locationProvider = locationProvider
    }

    func locate() async {
        myLocation = await locationProvider.current()?.coordinate
    }

    func member(id: UUID) -> FamilyMember? {
        family.members.first { $0.id == id }
    }

    var membersNeedingHelp: [FamilyMember] {
        family.members.filter { $0.status == .needHelp }
    }

    var membersOnMap: [FamilyMember] {
        family.members.filter { $0.sharedCoordinate != nil }
    }

    // While someone hasn't answered, the screen keeps checking
    var isWaitingForAnswers: Bool {
        family.members.contains { $0.status == .waiting }
    }

    func distance(to member: FamilyMember) -> String? {
        guard let myLocation, let coordinate = member.sharedCoordinate else { return nil }
        let meters = CLLocation(latitude: myLocation.latitude, longitude: myLocation.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        return "a " + Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    func load() async {
        needsSignIn = false
        let waiting = family.members.filter { $0.status == .waiting }
        do {
            family = try await service.fetchFamily()
            loadError = nil
            announceAnswers(from: waiting)
        } catch APIError.server(status: 401, _) {
            needsSignIn = true
        } catch {
            // Only blocks the screen if there was nothing to show yet
            if !hasLoaded { loadError = error.localizedDescription }
        }
        hasLoaded = true
    }

    func askIfOK(_ member: FamilyMember) async {
        if await perform({ try await $0.askIfOK(memberID: member.id) }) {
            notice = "Le preguntamos a \(member.firstName). Te avisamos cuando conteste."
        }
    }

    @discardableResult
    func answer(_ answer: WellbeingAnswer) async -> Bool {
        let asker = family.wellbeingRequest?.fromName.split(separator: " ").first.map(String.init) ?? "tu familia"
        guard await perform({ try await $0.answer(answer) }) else { return false }
        notice = answer == .ok
            ? "Le avisamos a \(asker) que estás bien."
            : "Le avisamos a tu familia que necesitas ayuda."
        return true
    }

    func respond(to invitation: FamilyInvitation, accept: Bool) async {
        if await perform({ try await $0.respondToInvitation(id: invitation.id, accept: accept) }), accept {
            notice = "Ya estás en la familia de \(invitation.fromName ?? "quien te invitó")."
        }
    }

    func cancel(_ invitation: FamilyInvitation) async {
        if await perform({ try await $0.cancelInvitation(id: invitation.id) }) {
            notice = "Cancelaste la invitación de \(invitation.name)."
        }
    }

    @discardableResult
    func remove(_ member: FamilyMember) async -> Bool {
        guard await perform({ try await $0.removeMember(id: member.id) }) else { return false }
        notice = "\(member.firstName) ya no está en tu familia."
        return true
    }

    func setSharesLocation(_ shares: Bool) async {
        await perform { try await $0.setSharesLocation(shares) }
    }

    // MARK: - Invitations

    // nil when the form is fine, otherwise what to tell the user
    func validateInvitation(name: String, contact: String) -> String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Escribe su nombre"
        }
        let contact = Self.normalizedContact(contact)
        guard Self.isPhone(contact) || Self.isEmail(contact) else {
            return "Escribe un celular de 10 números o un correo"
        }
        if family.sentInvitations.contains(where: { $0.contact == contact }) {
            return "Ya le mandaste una invitación"
        }
        return nil
    }

    // nil when it was sent, otherwise the message to show in the form
    func invite(name: String, contact: String, relationship: String) async -> String? {
        if let message = validateInvitation(name: name, contact: contact) { return message }
        let name = name.trimmingCharacters(in: .whitespaces)
        isBusy = true
        defer { isBusy = false }
        do {
            family = try await service.invite(name: name, contact: Self.normalizedContact(contact),
                                              relationship: relationship)
            notice = "Le enviamos la invitación a \(name)."
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Reports

    // The report goes to where the member is, not where I am
    func report(for member: FamilyMember) -> (EmergencyReport, EmergencyLocation?) {
        var report = EmergencyReport()
        report.reportingFor = .familyMember
        report.patientName = member.name
        if member.status == .needHelp {
            report.reason = "Avisó que necesita ayuda"
        }

        guard let coordinate = member.sharedCoordinate else { return (report, nil) }
        let updated = member.updatedAt.formatted(.relative(presentation: .named))
        let location = EmergencyLocation(coordinate: coordinate,
                                         address: "Ubicación de \(member.firstName), compartida \(updated)",
                                         accuracyMeters: 20)
        return (report, location)
    }

    // MARK: - Helpers

    private func announceAnswers(from waiting: [FamilyMember]) {
        let answered = waiting.compactMap { old in member(id: old.id) }.filter { $0.status != .waiting }
        guard let first = answered.first else { return }
        notice = first.status == .needHelp
            ? "\(first.firstName) contestó que necesita ayuda."
            : "\(first.firstName) contestó que está bien."
    }

    @discardableResult
    private func perform(_ action: (FamilyServicing) async throws -> Family) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            family = try await action(service)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    static func normalizedContact(_ contact: String) -> String {
        let trimmed = contact.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.contains("@") { return trimmed }
        return trimmed.filter(\.isNumber)
    }

    private static func isPhone(_ contact: String) -> Bool {
        contact.count == 10 && contact.allSatisfy(\.isNumber)
    }

    private static func isEmail(_ contact: String) -> Bool {
        let parts = contact.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !contact.contains(" ")
    }
}
