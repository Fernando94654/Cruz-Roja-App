import SwiftUI

struct ReporteVecinal: Identifiable {
    let id = UUID()
    let titulo: String
    let distancia: String
    var confirmaciones: Int
    let expira: String
    var confirmado = false
}

struct AlertasView: View {
    @State private var vecinales = [
        ReporteVecinal(titulo: "Calle inundada a 400 m", distancia: "400 m", confirmaciones: 6, expira: "3 h"),
        ReporteVecinal(titulo: "Semáforo apagado en el cruce", distancia: "250 m", confirmaciones: 2, expira: "2 h"),
    ]
    @State private var nuevo = false

    var body: some View {
        NavigationStack {
            List {
                Section("Protección Civil") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "cloud.heavyrain.fill")
                            .font(.title2)
                            .foregroundStyle(Color.rojo)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lluvia intensa en tu zona")
                                .font(.headline)
                            Text("Evita cruzar calles inundadas y mantente en un lugar seguro.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Alerta oficial · hace 20 min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Reportes de vecinos") {
                    ForEach($vecinales) { $r in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(r.titulo).font(.headline)
                            Text("Confirmado por \(r.confirmaciones) vecinos · expira en \(r.expira)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(r.confirmado ? "Confirmado" : "Confirmar") {
                                r.confirmado = true
                                r.confirmaciones += 1
                            }
                            .buttonStyle(.bordered)
                            .tint(.primary)
                            .disabled(r.confirmado)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Alertas")
            .safeAreaInset(edge: .bottom) {
                Button {
                    nuevo = true
                } label: {
                    Label("Reportar algo en mi zona", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .padding()
            }
            .sheet(isPresented: $nuevo) {
                NuevoReporteVecinal()
            }
        }
    }
}

struct NuevoReporteVecinal: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tipo = "Inundación"
    @State private var detalle = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $tipo) {
                    ForEach(["Inundación", "Semáforo", "Accidente", "Árbol caído", "Otro"], id: \.self) {
                        Text($0)
                    }
                }
                TextField("Qué está pasando", text: $detalle, axis: .vertical)
                Label("Se usará tu ubicación actual", systemImage: "location.fill")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Nuevo reporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    AlertasView()
}
