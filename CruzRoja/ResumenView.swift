import SwiftUI

struct ResumenView: View {
    var reporte: Reporte

    var body: some View {
        List {
            if reporte.enviado {
                Section("Seguimiento") {
                    Label("Ubicación compartida por SMS y enlace", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.primary)
                    paso("Recibido", "17:42", hecho: true)
                    paso("Unidad asignada", "Ambulancia 214 · 17:43", hecho: true)
                    paso("En camino", "≈ 8 min", hecho: false)
                }

                Section {
                    NavigationLink(value: Pantalla.auxilios) {
                        Label("Ver instrucciones de primeros auxilios", systemImage: "bandage")
                    }
                }
            }

            Section {
                fila("Para", reporte.nombre.map { "\(reporte.paraQuien) (\($0))" } ?? reporte.paraQuien)
                fila("Motivo", reporte.motivo)
                fila("Lesionados", "\(reporte.lesionados)")
                fila("Lesión principal", reporte.lesion)
                fila("Lugar", reporte.lugar)
                fila("Estado mental", reporte.estadoMental)
                fila("Respiración", reporte.respiracion)
                fila("Color de piel", reporte.piel)
                fila("Referencia", reporte.referencia)
                fila("Ubicación", "±5 m")
            } header: {
                Text("Resumen del reporte")
            } footer: {
                Text("Generado a partir de lo que dictaste. Revisa que esté correcto.")
            }

            if !reporte.enviado {
                Section {
                    Button {
                        withAnimation { reporte.enviado = true }
                    } label: {
                        Text("Enviar a Cruz Roja")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.rojo)
                }
            }
        }
        .navigationTitle(reporte.enviado ? "Reporte enviado" : "Revisar reporte")
        .navigationBarTitleDisplayMode(.inline)
    }

    func fila(_ titulo: String, _ valor: String) -> some View {
        LabeledContent(titulo, value: valor.isEmpty ? "—" : valor)
    }

    func paso(_ titulo: String, _ detalle: String, hecho: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: hecho ? "checkmark.circle.fill" : "circle.dotted")
                .font(.title3)
                .foregroundStyle(hecho ? Color.primary : Color.rojo)
            VStack(alignment: .leading) {
                Text(titulo).font(.body.weight(hecho ? .regular : .semibold))
                Text(detalle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let r = Reporte()
    r.dictar()
    return NavigationStack { ResumenView(reporte: r) }
}
