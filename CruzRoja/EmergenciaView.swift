import SwiftUI
import MapKit

struct EmergenciaView: View {
    @State private var ruta: [Pantalla] = {
        switch demo {
        case "reporte", "signos": return [.reporte]
        case "resumen", "enviado": return [.reporte, .resumen]
        case "auxilios": return [.reporte, .resumen, .auxilios]
        case "guia": return [.reporte, .resumen, .auxilios, .guia(emergencias[0])]
        default: return []
        }
    }()
    @State private var reporte: Reporte = {
        let r = Reporte()
        if ["reporte", "signos", "resumen", "enviado", "auxilios", "guia"].contains(demo) { r.dictar() }
        if demo == "enviado" { r.enviado = true }
        return r
    }()
    @State private var cuenta = demo == "cuenta"
    @State private var presionando = false
    @State private var confirmar = demo == "confirmar"

    var body: some View {
        NavigationStack(path: $ruta) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Ubicación exacta, ±5 m", systemImage: "location.fill")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.gray.opacity(0.12), in: Capsule())

                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: monterrey,
                            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)))) {
                            Marker("Tú", coordinate: monterrey)
                                .tint(.black)
                        }
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text(direccion)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 24)

                    // hay que mantenerlo presionado para evitar toques por error
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                        Text("Reportar emergencia")
                            .font(.marca(24))
                        Text(presionando ? "Sigue presionando…" : "Mantén presionado 3 segundos")
                            .font(.subheadline)
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(alignment: .leading) {
                        ZStack(alignment: .leading) {
                            Color.rojo
                            GeometryReader { geo in
                                Color.black.opacity(0.25)
                                    .frame(width: presionando ? geo.size.width : 0)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .scaleEffect(presionando ? 0.97 : 1)
                    .onLongPressGesture(minimumDuration: 3, maximumDistance: 40) {
                        presionando = false
                        confirmar = true
                    } onPressingChanged: { p in
                        withAnimation(p ? .linear(duration: 3) : .easeOut(duration: 0.2)) {
                            presionando = p
                        }
                    }
                    .sensoryFeedback(.warning, trigger: confirmar)

                    Label("Antes de enviar te pediremos confirmar y tendrás 5 segundos para cancelar.", systemImage: "hand.raised")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Emergencia")
            .pantallas(reporte)
        }
        .alert("¿Reportar una emergencia?", isPresented: $confirmar) {
            Button("Cancelar", role: .cancel) {}
            Button("Sí, reportar", role: .destructive) { cuenta = true }
        } message: {
            Text("Se enviará tu ubicación exacta a Cruz Roja.")
        }
        .fullScreenCover(isPresented: $cuenta) {
            CuentaRegresivaView {
                cuenta = false
                ruta = [.reporte]
            }
        }
    }
}

struct CuentaRegresivaView: View {
    var alTerminar: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var segundos = 5

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Enviando reporte en")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("\(segundos)")
                .font(.marca(110))
                .foregroundStyle(.white)
                .frame(width: 210, height: 210)
                .background(Color.rojo, in: Circle())
                .contentTransition(.numericText())
            Text("Se compartirá tu ubicación con Cruz Roja")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Cancelar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            Text("¿Fue un error? Cancela antes de que termine.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            if demo == "cuenta" { segundos = 3; return } // fijo para la captura
            while segundos > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                withAnimation { segundos -= 1 }
            }
            alTerminar()
        }
    }
}

extension View {
    // las mismas pantallas del flujo se usan desde Emergencia y desde Familia
    func pantallas(_ reporte: Reporte) -> some View {
        navigationDestination(for: Pantalla.self) { p in
            switch p {
            case .reporte: ReporteView(reporte: reporte)
            case .resumen: ResumenView(reporte: reporte)
            case .auxilios: PrimerosAuxiliosView()
            case .guia(let e): GuiaView(emergencia: e)
            }
        }
    }
}

#Preview {
    EmergenciaView()
}
