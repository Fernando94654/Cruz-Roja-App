import SwiftUI

// For previews: ViewModels read the guide cache once at init, so GET /guides has to land before the view is built
struct GuidesRefreshed<Content: View>: View {
    let container: AppContainer
    @ViewBuilder let content: () -> Content
    @State private var isReady = false

    var body: some View {
        if isReady {
            content()
        } else {
            ProgressView()
                .task {
                    await container.refreshGuides()
                    isReady = true
                }
        }
    }
}
