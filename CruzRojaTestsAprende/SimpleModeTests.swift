import Foundation
import Testing
@testable import CruzRoja

private func profile(contacts: [EmergencyContact]) -> MedicalProfile {
    var profile = MedicalProfile.sample
    profile.contacts = contacts
    return profile
}

@Suite("Simple mode buttons")
struct SimpleModeTests {
    @Test func withoutProfileOnlyReportAnd911() {
        #expect(SimpleAction.actions(for: nil) == [.report, .call911])
    }

    @Test func profileAddsTwoContactsAndTheQRInAFixedOrder() {
        let actions = SimpleAction.actions(for: profile(contacts: [
            EmergencyContact(name: "Ana López", relationship: "Hija", phone: "81 1234 5678"),
            EmergencyContact(name: "Jorge López", relationship: "Esposo", phone: "8110000003"),
            EmergencyContact(name: "Lucía López", relationship: "Nieta", phone: "8110000004"),
        ]))
        #expect(actions == [
            .report,
            .call911,
            .callContact(name: "Ana López", relationship: "Hija", phone: "8112345678"),
            .callContact(name: "Jorge López", relationship: "Esposo", phone: "8110000003"),
            .showMedicalQR,
        ])
    }

    @Test func contactsWithoutNameOrPhoneAreSkipped() {
        let actions = SimpleAction.actions(for: profile(contacts: [
            EmergencyContact(name: "  ", relationship: "Hija", phone: "8112345678"),
            EmergencyContact(name: "Jorge", relationship: "", phone: "sin número"),
        ]))
        #expect(actions == [.report, .call911, .showMedicalQR])
    }

    @Test func titlesAndPhoneLinks() {
        let withRelationship = SimpleAction.callContact(name: "Ana", relationship: "Hija", phone: "8112345678")
        let withoutRelationship = SimpleAction.callContact(name: "Ana", relationship: "", phone: "8112345678")
        #expect(withRelationship.title == "Llamar a Ana (Hija)")
        #expect(withoutRelationship.title == "Llamar a Ana")
        #expect(withRelationship.phoneURL == URL(string: "tel://8112345678"))
        #expect(SimpleAction.call911.phoneURL == URL(string: "tel://911"))
        #expect(SimpleAction.report.phoneURL == nil)
    }

    @Test func onlyReportAnd911AreEmergencyStyled() {
        #expect(SimpleAction.report.isEmergency)
        #expect(SimpleAction.call911.isEmergency)
        #expect(!SimpleAction.showMedicalQR.isEmergency)
    }
}
