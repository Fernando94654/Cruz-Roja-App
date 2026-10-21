import SwiftUI

struct ContentView: View {

    @State var vm = AlertasViewModel()
    @State var mostrarFormulario = false

    var body: some View {

        NavigationStack {

            List {

                Section("Alertas oficiales") {
                    ForEach(vm.alertasOficiales) { alerta in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alerta.titulo)
                                .font(.headline)
                            Text("\(alerta.fuente) · \(alerta.zona)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(alerta.fecha.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Reportes de vecinos") {
                    ForEach(vm.reportesVigentes) { reporte in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reporte.titulo)
                                    .font(.headline)
                                Text(reporte.categoria)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Expira en \(reporte.expira, style: .relative)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                vm.confirmar(reporte)
                            } label: {
                                Label("\(reporte.confirmaciones)",
                                      systemImage: reporte.yaConfirme ? "checkmark.circle.fill" : "checkmark.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Alertas")
            .toolbar {
                Button {
                    mostrarFormulario = true
                } label: {
                    Label("Reportar", systemImage: "plus")
                }
            }
            .sheet(isPresented: $mostrarFormulario) {
                NuevoReporteView(vm: vm)
            }
        }
    }
}

#Preview {
    ContentView()
}
