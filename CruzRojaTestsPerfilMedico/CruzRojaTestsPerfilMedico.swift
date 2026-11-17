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

    // TC-PM-10
    @Test("\"Sin alergias conocidas\" se distingue de no haberlas llenado")
    func noKnownAllergies() {
        var profile = MedicalProfile.sample
        profile.allergies = [MedicalProfile.noAllergies]
        #expect(profile.cleaned().allergies == ["Sin alergias conocidas"])

        // Si después agrega una alergia real, se quita el "Sin…"
        profile.allergies = [MedicalProfile.noAllergies, "Látex"]
        #expect(profile.cleaned().allergies == ["Látex"])

        // Vacío significa que no lo llenó
        #expect(MedicalProfile.text(for: []) == "Sin información")
    }

    // TC-PM-11
    @Test("Las palabras clave acomodan lo dictado en cada campo")
    func dictationRules() {
        let fields = RuleBasedProfileExtractor().fields(from:
            "Tengo 70 años, mi sangre es O positivo, soy diabético e hipertenso, soy alérgico a la penicilina y al látex, tomo metformina y losartán")

        #expect(fields.age == 70)
        #expect(fields.bloodType == .oPositive)
        #expect(fields.allergies == ["Penicilina", "Látex"])
        #expect(fields.conditions == ["Diabetes", "Hipertensión"])
        #expect(fields.medications == ["Metformina", "Losartán"])
    }

    // TC-PM-12
    @Test("Lo dictado se agrega sin borrar ni repetir lo que ya había")
    func dictationMergeKeepsExistingData() {
        var profile = MedicalProfile.sample   // ya tiene Asma y alergia a Penicilina
        profile.medications = [MedicalProfile.noMedications]
        var fields = ProfileFields()
        fields.allergies = ["penicilina", "Látex"]
        fields.conditions = ["Diabetes"]
        fields.medications = ["Metformina"]

        let result = profile.merging(fields)

        #expect(result.profile.allergies == ["Penicilina", "Látex"])
        #expect(result.profile.conditions == ["Asma", "Diabetes"])
        #expect(result.profile.medications == ["Metformina"])
        #expect(result.profile.fullName == "María López")
        #expect(result.added.count == 3)
    }

    // TC-PM-13
    @Test("La fecha de nacimiento dictada se llena; con solo la edad se pone una fecha aproximada")
    func dictationBirthDateAndAge() {
        let exact = RuleBasedProfileExtractor().fields(from: "Nací el 14 de marzo de 1958")
        #expect(exact.dateOfBirth == ProfileFields.birthDate(day: 14, month: 3, year: 1958))

        var empty = MedicalProfile()
        empty.fullName = "Rosa"
        var onlyAge = ProfileFields()
        onlyAge.age = 70
        let result = empty.merging(onlyAge)
        #expect(result.profile.age() == 70)
        #expect(result.ageNote != nil)
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
