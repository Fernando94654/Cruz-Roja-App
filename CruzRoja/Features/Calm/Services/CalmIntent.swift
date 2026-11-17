import AppIntents
import Observation

// Avisa a la pantalla de Emergencia que se pidio abrir Calma desde Siri o Atajos
@MainActor
@Observable
final class CalmLauncher {
    static let shared = CalmLauncher()
    private(set) var isPending = false

    func request() {
        isPending = true
    }

    // Regresa true una sola vez por cada peticion
    func consume() -> Bool {
        defer { isPending = false }
        return isPending
    }
}

// "Oye Siri, ayúdame a calmarme con CruzRoja"; tambien aparece en la app Atajos y se puede asignar al boton de accion
struct OpenCalmIntent: AppIntent {
    static let title: LocalizedStringResource = "Ayúdame a calmarme"
    static let description = IntentDescription("Abre la respiración guiada y el acompañante para calmarte.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CalmLauncher.shared.request()
        return .result()
    }
}

struct CalmShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenCalmIntent(),
            phrases: [
                "Ayúdame a calmarme con \(.applicationName)",
                "Necesito calmarme en \(.applicationName)",
                "Abre calma en \(.applicationName)",
            ],
            shortTitle: "Calmarme",
            systemImageName: "wind"
        )
    }
}
