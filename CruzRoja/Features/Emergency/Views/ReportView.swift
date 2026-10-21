import SwiftUI

struct ReporteView: View {
    @Bindable var reporte: Reporte
    @State private var escuchando = false

    var body: some View {
        ScrollViewReader { scroll in
        Form {
            Section("¿Para quién?") {
                Picker("¿Para quién?", selection: $reporte.paraQuien) {
                    ForEach(["Para mí", "Para otra persona", "Para un familiar"], id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if let nombre = reporte.nombre {
                    Label("Perfil médico de \(nombre) cargado", systemImage: "person.text.rectangle")
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    escuchando = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { reporte.dictar() }
                        escuchando = false
                    }
                } label: {
                    Label(escuchando ? "Escuchando…" : "Dictar", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(escuchando)
            } footer: {
                Text("Describe lo que pasa y llenamos el reporte por ti.")
            }

            Section("Incidente") {
                campo("Motivo", $reporte.motivo)
                Stepper("Lesionados: \(reporte.lesionados)", value: $reporte.lesionados, in: 1...20)
                campo("Lesión principal", $reporte.lesion)
                campo("Lugar", $reporte.lugar)
            }

            Section("Ubicación") {
                Label {
                    VStack(alignment: .leading) {
                        Text(direccion)
                        Text("Automática · ±5 m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "location.fill")
                }
                campo("Referencia", $reporte.referencia)
            }

            Section("Estado del paciente") {
                signo("Estado mental", $reporte.estadoMental, ["Alerta", "Confundido", "Inconsciente"])
                    .id("signos")
                signo("Respiración", $reporte.respiracion, ["Normal", "Con dificultad", "No respira"])
                signo("Color de piel", $reporte.piel, ["Normal", "Pálida", "Azulada"])
            }
        }
        .onAppear {
            if demo == "signos" { scroll.scrollTo("signos", anchor: .top) }
        }
        }
        .navigationTitle("Reporte")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink(value: Pantalla.resumen) {
                Text("Continuar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .padding()
            .background(.bar)
        }
    }

    func campo(_ titulo: String, _ texto: Binding<String>) -> some View {
        LabeledContent(titulo) {
            TextField(titulo, text: texto)
                .multilineTextAlignment(.trailing)
        }
    }

    func signo(_ titulo: String, _ valor: Binding<String>, _ opciones: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker(titulo, selection: valor) {
                ForEach(opciones, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { ReporteView(reporte: Reporte()) }
}
