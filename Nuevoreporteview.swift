import SwiftUI

struct NuevoReporteView: View {

    var vm: AlertasViewModel
    @Environment(\.dismiss) var dismiss

    @State var categoria = "Inundación"
    @State var titulo = ""

    let categorias = ["Inundación", "Calle bloqueada", "Árbol caído", "Apagón", "Incendio", "Otro"]

    var body: some View {

        NavigationStack {

            Form {
                Picker("Tipo", selection: $categoria) {
                    ForEach(categorias, id: \.self) { c in
                        Text(c).tag(c)
                    }
                }
                TextField("¿Qué pasó? Ej. Calle inundada", text: $titulo)
            }
            .navigationTitle("Nuevo reporte")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicar") {
                        vm.agregarReporte(categoria: categoria, titulo: titulo)
                        dismiss()
                    }
                    .disabled(titulo.isEmpty)
                }
            }
        }
    }
}
