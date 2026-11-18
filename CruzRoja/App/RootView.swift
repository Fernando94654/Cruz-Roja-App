import SwiftUI

enum AppTab {
    case emergency, family, alerts, learn, profile
}

struct RootView: View {
    let container: AppContainer

    @State private var tab: AppTab = {
        switch DemoMode.current {
        case "family": .family
        case "alerts": .alerts
        case "learn", "lesson": .learn
        case "profile", "login": .profile
        default: .emergency
        }
    }()

    @AppStorage(SimpleMode.storageKey) private var isSimpleMode = false

    var body: some View {
        Group {
            if isSimpleMode || DemoMode.isActive("simple") {
                SimpleHomeView(container: container)
            } else {
                tabs
            }
        }
        .task {
            async let guides: Void = container.refreshGuides()
            async let knowledge: Void = container.refreshKnowledge()
            _ = await (guides, knowledge)
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            EmergencyView(container: container)
                .tabItem { Label("Emergencia", systemImage: "sos") }
                .tag(AppTab.emergency)
            FamilyView(container: container)
                .tabItem { Label("Familia", systemImage: "person.2") }
                .tag(AppTab.family)
            AlertsView(viewModel: container.makeAlertsViewModel())
                .tabItem { Label("Alertas", systemImage: "bell") }
                .tag(AppTab.alerts)
            LearnView(container: container)
                .tabItem { Label("Aprende", systemImage: "play.rectangle") }
                .tag(AppTab.learn)
            MedicalProfileView(container: container)
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(Color.brandRed)
    }
}

#Preview {
    RootView(container: .preview)
}
