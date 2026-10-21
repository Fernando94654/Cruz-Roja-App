import SwiftUI

// de mentira: cuenta regresiva 4 veces más rápida para las demos
@MainActor
@Observable
final class Ambulancia {
    static let actual = Ambulancia()

    let unidad = "Ambulancia 214"
    private(set) var restantes = 0
    private(set) var total = 0
    @ObservationIgnored private var tarea: Task<Void, Never>?

    var enCamino: Bool { tarea != nil }
    var llego: Bool { enCamino && restantes == 0 }
    var avance: Double { total > 0 ? 1 - Double(restantes) / Double(total) : 0 }
    var tiempo: String { String(format: "%d:%02d", restantes / 60, restantes % 60) }

    var estado: String {
        if llego { return "La ambulancia llegó" }
        return switch restantes {
        case 1..<60: "Llegando"
        default: "En camino"
        }
    }

    func solicitar(segundos: Int = 480) {
        guard !enCamino else { return }
        total = segundos
        restantes = segundos
        tarea = Task {
            while restantes > 0 {
                try? await Task.sleep(for: .seconds(0.25))
                if Task.isCancelled { return }
                restantes -= 1
            }
        }
    }
}

struct BarraAmbulancia: View {
    let ambulancia: Ambulancia

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: ambulancia.llego ? "checkmark.circle.fill" : "cross.case.fill")
                    .font(.title3)
                    .foregroundStyle(ambulancia.llego ? Color.primary : Color.rojo)
                    .symbolEffect(.pulse, isActive: !ambulancia.llego)
                VStack(alignment: .leading) {
                    Text(ambulancia.estado).font(.headline)
                    Text(ambulancia.unidad).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !ambulancia.llego {
                    Text(ambulancia.tiempo)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                }
            }
            ProgressView(value: ambulancia.avance)
                .tint(Color.rojo)
        }
        .padding()
        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}
