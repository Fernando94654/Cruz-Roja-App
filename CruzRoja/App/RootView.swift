import SwiftUI

enum Tab {
    case emergencia, familia, alertas, aprende, perfil
}

struct ContentView: View {
    @State private var tab: Tab = {
        switch demo {
        case "familia": return .familia
        case "alertas": return .alertas
        case "aprende", "leccion": return .aprende
        case "perfil", "login": return .perfil
        default: return .emergencia
        }
    }()

    var body: some View {
        TabView(selection: $tab) {
            EmergenciaView()
                .tabItem { Label("Emergencia", systemImage: "sos") }
                .tag(Tab.emergencia)
            FamiliaView()
                .tabItem { Label("Familia", systemImage: "person.2") }
                .tag(Tab.familia)
            AlertasView()
                .tabItem { Label("Alertas", systemImage: "bell") }
                .tag(Tab.alertas)
            AprendeView()
                .tabItem { Label("Aprende", systemImage: "play.rectangle") }
                .tag(Tab.aprende)
            PerfilView()
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                .tag(Tab.perfil)
        }
        .tint(Color.rojo)
    }
}

#Preview {
    ContentView()
}
