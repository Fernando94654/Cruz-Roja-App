import Foundation

// Crea el ViewModel de los familiares
extension AppContainer {
    func makeDependentProfilesViewModel() -> DependentProfilesViewModel {
        if DemoMode.offline || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return DependentProfilesViewModel(
                service: Self.previewDependentsService,
                cache: DependentProfilesCache(directory: FileManager.default.temporaryDirectory)
            )
        }
        return DependentProfilesViewModel(service: DependentProfilesAPIService())
    }

    private static let previewDependentsService = MockDependentProfilesService()
}
