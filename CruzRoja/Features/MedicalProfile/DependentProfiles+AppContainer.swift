import Foundation

// Factory for the family members' profiles.
// Kept in an extension instead of AppContainer's initializer to avoid merge conflicts with the
// emergency-report branch, which also edits AppContainer; it can move there once both are merged.
extension AppContainer {
    func makeDependentProfilesViewModel() -> DependentProfilesViewModel {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return DependentProfilesViewModel(
                service: Self.previewDependentsService,
                cache: DependentProfilesCache(directory: FileManager.default.temporaryDirectory)
            )
        }
        return DependentProfilesViewModel(service: DependentProfilesAPIService())
    }

    private static let previewDependentsService = MockDependentProfilesService()
}
