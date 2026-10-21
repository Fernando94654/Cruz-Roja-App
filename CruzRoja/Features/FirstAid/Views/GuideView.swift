import SwiftUI

struct GuiaView: View {
    let emergencia: Emergencia
    @State private var paso = 0
    @State private var restante: Int?
    @State private var latido = false

    private let voz = Voz.compartida
    private let ambulancia = Ambulancia.actual

    var actual: PasoGuia { emergencia.pasos[paso] }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BarraAmbulancia(ambulancia: ambulancia)

            VStack(alignment: .leading, spacing: 8) {
                Text("Paso \(paso + 1) de \(emergencia.pasos.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(paso + 1), total: Double(emergencia.pasos.count))
                    .tint(Color.rojo)
            }

            Spacer()

            HStack {
                Spacer()
                indicador
                Spacer()
            }

            Text(actual.titulo)
                .font(.marca(28))
            Text(actual.instruccion)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    withAnimation { paso -= 1 }
                } label: {
                    Text("Anterior").frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(paso == 0)

                Button {
                    voz.decir(actual.instruccion)
                } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    withAnimation { paso += 1 }
                } label: {
                    Text("Siguiente").frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(paso == emergencia.pasos.count - 1)
            }
            .tint(.black)

            Text("Basado en protocolos de Cruz Roja")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .navigationTitle(emergencia.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                voz.silenciada.toggle()
            } label: {
                Image(systemName: voz.silenciada ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .tint(.primary)
        }
        .task(id: paso) { await correrPaso() }
        .task(id: paso) { await marcarRitmo() }
        .onChange(of: ambulancia.llego) {
            if ambulancia.llego {
                voz.decir("La ambulancia llegó. Cuéntale a los paramédicos qué pasó y qué hiciste.")
            }
        }
        .onAppear { ambulancia.solicitar() }
        .onDisappear { voz.callar() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: latido)
    }

    var indicador: some View {
        ZStack {
            Circle().fill(.gray.opacity(0.12))
            if let total = actual.segundos, let restante {
                Circle()
                    .trim(from: 0, to: Double(restante) / Double(total))
                    .stroke(Color.rojo, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: restante)
                    .padding(4)
            }
            VStack(spacing: 6) {
                Image(systemName: actual.icono)
                    .font(.system(size: 52))
                    .foregroundStyle(Color.rojo)
                    .scaleEffect(actual.ritmo != nil && latido ? 1.15 : 1)
                if let restante {
                    Text(String(format: "%d:%02d", restante / 60, restante % 60))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                if let ritmo = actual.ritmo {
                    Text("\(ritmo) por minuto")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 190, height: 190)
    }

    func correrPaso() async {
        voz.decir("\(actual.titulo). \(actual.instruccion)")
        restante = actual.segundos
        while let r = restante, r > 0 {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            restante = r - 1
        }
        if restante == 0 { voz.decir("Tiempo cumplido.") }
    }

    func marcarRitmo() async {
        guard let ritmo = actual.ritmo else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60.0 / Double(ritmo)))
            withAnimation(.easeOut(duration: 0.1)) { latido.toggle() }
        }
    }
}

#Preview {
    NavigationStack { GuiaView(emergencia: emergencias[0]) }
}
