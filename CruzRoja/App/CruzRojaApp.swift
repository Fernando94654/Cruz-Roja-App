import SwiftUI

@main
struct CruzRojaApp: App {
    private let container = AppContainer.live

    init() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: UIFont(name: "HelveticaNeue-Bold", size: 34)!]
        bar.titleTextAttributes = [.font: UIFont(name: "HelveticaNeue-Bold", size: 17)!]
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
