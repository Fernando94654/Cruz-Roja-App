//
//  CruzRojaTestsPerfilMedico.swift
//  CruzRojaTestsPerfilMedico
//
//  Unit tests for the medical profile feature (Fernando Robles). Run with ⌘U in Xcode.
//

import Foundation
import Testing
@testable import CruzRoja

// Service that always fails, to simulate having no connection
private struct OfflineDependentsService: DependentProfilesServicing {
    func fetchDependents(userID: UUID) async throws -> [DependentProfile] { throw APIError.offline }
    func createDependent(_ dependent: DependentProfile, userID: UUID) async throws -> DependentProfile { throw APIError.offline }
    func updateDependent(_ dependent: DependentProfile, userID: UUID) async throws -> DependentProfile { throw APIError.offline }
    func deleteDependent(id: UUID, userID: UUID) async throws { throw APIError.offline }
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
}
