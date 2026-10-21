import SwiftUI

@main
struct CruzRojaApp: App {
    init() {
        let barra = UINavigationBar.appearance()
        barra.largeTitleTextAttributes = [.font: UIFont(name: "HelveticaNeue-Bold", size: 34)!]
        barra.titleTextAttributes = [.font: UIFont(name: "HelveticaNeue-Bold", size: 17)!]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
