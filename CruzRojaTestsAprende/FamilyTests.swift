import Foundation
import Testing
@testable import CruzRoja

// Círculo familiar, the test case ids are in docs/TestCases_Familia.xlsx
@MainActor
struct FamilyTests {
    // Sample family: Ana needs help, Jorge is fine, Lucía hasn't answered and doesn't share her location
    private func makeViewModel(answerDelay: TimeInterval = 0) async -> FamilyViewModel {
        let viewModel = FamilyViewModel(service: MockFamilyService(answerDelay: answerDelay),
                                        locationProvider: FixedLocationProvider())
        await viewModel.load()
        return viewModel
    }

    private func member(_ firstName: String, in viewModel: FamilyViewModel) throws -> FamilyMember {
        try #require(viewModel.family.members.first { $0.firstName == firstName })
    }

    // TC-FA-01
    @Test func invitaValido() async {
        let viewModel = await makeViewModel()
        let error = await viewModel.invite(name: "Pedro", contact: "81 1000 0009", relationship: "Nieto")
        #expect(error == nil)
        #expect(viewModel.family.sentInvitations.first?.contact == "8110000009")
        #expect(viewModel.notice == "Le enviamos la invitación a Pedro.")
    }

    // TC-FA-02
    @Test(arguments: ["8112", "pedro", "pedro@correo", "  "])
    func contactoInvalido(contact: String) async {
        let viewModel = await makeViewModel()
        let error = await viewModel.invite(name: "Pedro", contact: contact, relationship: "Nieto")
        #expect(error == "Escribe un celular de 10 números o un correo")
        #expect(viewModel.family.sentInvitations.count == 1)
    }

    // TC-FA-03, the sample already has an invitation to 8110000006
    @Test func invitacionRepetida() async {
        let viewModel = await makeViewModel()
        let error = await viewModel.invite(name: "Otro", contact: "81 1000 0006", relationship: "Otro")
        #expect(error == "Ya le mandaste una invitación")
    }

    // TC-FA-04
    @Test func aceptarInvitacion() async throws {
        let viewModel = await makeViewModel()
        let invitation = try #require(viewModel.family.receivedInvitations.first)
        await viewModel.respond(to: invitation, accept: true)
        #expect(viewModel.family.receivedInvitations.isEmpty)
        #expect(viewModel.family.members.contains { $0.name == "Carmen Ruiz" })
        #expect(viewModel.notice == "Ya estás en la familia de Carmen Ruiz.")
    }

    // TC-FA-05
    @Test func preguntarSiEstaBien() async throws {
        let viewModel = await makeViewModel(answerDelay: 60)
        await viewModel.askIfOK(try member("Jorge", in: viewModel))
        #expect(try member("Jorge", in: viewModel).status == .waiting)
        #expect(viewModel.isWaitingForAnswers)
        #expect(viewModel.notice == "Le preguntamos a Jorge. Te avisamos cuando conteste.")
    }

    // TC-FA-06
    @Test func avisaCuandoContesta() async throws {
        let viewModel = await makeViewModel()
        await viewModel.askIfOK(try member("Jorge", in: viewModel))
        await viewModel.load()
        #expect(try member("Jorge", in: viewModel).status == .ok)
        #expect(viewModel.notice == "Jorge contestó que está bien.")
    }

    // TC-FA-07
    @Test func responderEstoyBien() async {
        let viewModel = await makeViewModel()
        #expect(viewModel.family.wellbeingRequest != nil)
        await viewModel.answer(.ok)
        #expect(viewModel.family.wellbeingRequest == nil)
        #expect(viewModel.notice == "Le avisamos a Jorge que estás bien.")
    }

    // TC-FA-08
    @Test func mapaSoloQuienComparte() async {
        let viewModel = await makeViewModel()
        #expect(viewModel.membersOnMap.map(\.firstName) == ["Ana", "Jorge"])
        #expect(viewModel.membersNeedingHelp.map(\.firstName) == ["Ana"])
    }

    // TC-FA-09
    @Test func rutasConCoordenadas() {
        let coordinate = Coordinate(latitude: 25.66, longitude: -100.3)
        #expect(Directions.appleMaps(to: coordinate).absoluteString.contains("daddr=25.66,-100.3"))
        #expect(Directions.googleMaps(to: coordinate).absoluteString.contains("destination=25.66,-100.3"))
    }

    // TC-FA-10
    @Test func dejarDeCompartir() async {
        let viewModel = await makeViewModel()
        await viewModel.setSharesLocation(false)
        #expect(viewModel.family.sharesLocation == false)
    }

    // TC-FA-11, the report goes to where Ana is
    @Test func reporteParaFamiliar() async throws {
        let viewModel = await makeViewModel()
        let ana = try member("Ana", in: viewModel)
        let (report, location) = viewModel.report(for: ana)
        #expect(report.reportingFor == .familyMember)
        #expect(report.patientName == "Ana López")
        #expect(report.reason == "Avisó que necesita ayuda")
        #expect(location?.coordinate == ana.coordinate)
    }
}
