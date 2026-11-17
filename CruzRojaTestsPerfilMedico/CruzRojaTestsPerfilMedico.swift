// Pruebas automáticas del perfil médico (Fernando Robles)

import Foundation
import Testing
@testable import CruzRoja

// Servicio falso que simula no tener internet
private struct OfflineDependentsService: DependentProfilesServicing {
    func fetchDependents() async throws -> [DependentProfile] { throw APIError.offline }
    func createDependent(_ dependent: DependentProfile) async throws -> DependentProfile { throw APIError.offline }
    func updateDependent(_ dependent: DependentProfile) async throws -> DependentProfile { throw APIError.offline }
    func deleteDependent(id: UUID) async throws { throw APIError.offline }
}

// Guarda el resumen médico que se envía con cada reporte
private actor RecordingReportService: EmergencyReportServicing {
    var medicalSummaries: [String?] = []

    func send(_ report: EmergencyReport, location: EmergencyLocation, summary: String, medicalSummary: String?) async throws -> SentReport {
        medicalSummaries.append(medicalSummary)
        return SentReport(id: "1", shareURL: "http://localhost:8000/r/abc")
    }
}

private func emptyCache() -> DependentProfilesCache {
    DependentProfilesCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
}

@Suite("Perfil médico")
@MainActor
struct CruzRojaTestsPerfilMedico {

    // TC-PM-02
    @Test("Un teléfono de contacto solo es válido con 10 dígitos")
    func phoneValidation() {
        #expect(MedicalProfile.isValidPhone("81 1234 5678"))
        #expect(!MedicalProfile.isValidPhone("8112"))
    }

    // TC-PM-05
    @Test("Agregar un familiar lo guarda y aparece en la lista")
    func addsDependent() async {
        let viewModel = DependentProfilesViewModel(service: MockDependentProfilesService(dependents: []), cache: emptyCache())
        await viewModel.load()

        var grandma = DependentProfile(relationship: "Abuela")
        grandma.profile.fullName = "Rosa Martínez"

        #expect(await viewModel.save(grandma))
        #expect(viewModel.dependents.map(\.displayName) == ["Rosa Martínez (Abuela)"])
    }

    // TC-PM-06
    @Test("Sin conexión se muestra la última lista guardada")
    func offlineUsesCache() async {
        let cache = emptyCache()
        cache.save([.sample])
        let viewModel = DependentProfilesViewModel(service: OfflineDependentsService(), cache: cache)

        await viewModel.load()

        #expect(viewModel.isShowingCachedCopy)
        #expect(viewModel.dependents.first?.fullName == "Rosa Martínez")
    }

    // TC-PM-08
    @Test("Al cerrar sesión se borra el perfil guardado en el teléfono")
    func clearRemovesSavedCopy() async {
        let cache = MedicalProfileCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let viewModel = MedicalProfileViewModel(service: MockMedicalProfileService(), cache: cache)
        await viewModel.load()
        #expect(cache.load() != nil)

        viewModel.clear()

        #expect(viewModel.profile == nil)
        #expect(cache.load() == nil)
    }

    // TC-PM-09
    @Test("El reporte para un familiar guardado lleva su perfil médico")
    func familyReportSendsDependentProfile() async {
        let grandma = DependentProfile.sample
        let service = RecordingReportService()
        let location = EmergencyLocation(coordinate: .monterrey, address: "Av. Eugenio Garza Sada 2501", accuracyMeters: 5)
        let viewModel = EmergencyReportViewModel(
            report: EmergencyReport(reportingFor: .familyMember),
            location: location,
            service: service,
            extractor: RuleBasedReportExtractor(),
            locationProvider: FixedLocationProvider(),
            dictation: SilentDictation(),
            medicalSummary: { "Mi perfil" },
            savedDependents: { [grandma] }
        )

        viewModel.selectDependent(grandma.id)
        #expect(await viewModel.send())

        #expect(viewModel.report.patientName == "Rosa Martínez")
        #expect(await service.medicalSummaries == [grandma.profile.reportSummary])
    }
}
