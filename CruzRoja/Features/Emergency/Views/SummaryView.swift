import SwiftUI

struct SummaryView: View {
    let viewModel: EmergencyReportViewModel

    private var report: EmergencyReport { viewModel.report }

    var body: some View {
        List {
            if viewModel.isSent {
                Section("Seguimiento") {
                    Label("Ubicación compartida por SMS y enlace", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.primary)
                    trackingStep("Recibido", "17:42", done: true)
                    trackingStep("Unidad asignada", "Ambulancia 214 · 17:43", done: true)
                    trackingStep("En camino", "≈ 8 min", done: false)
                }

                Section {
                    NavigationLink(value: EmergencyRoute.firstAid) {
                        Label("Ver instrucciones de primeros auxilios", systemImage: "bandage")
                    }
                }
            }

            Section {
                row("Para", viewModel.patientDescription)
                row("Motivo", report.reason)
                row("Lesionados", "\(report.injuredCount)")
                row("Lesión principal", report.injury)
                row("Lugar", report.place)
                row("Estado mental", report.mentalState)
                row("Respiración", report.breathing)
                row("Color de piel", report.skin)
                row("Referencia", report.reference)
                row("Ubicación", "±\(viewModel.location.accuracyMeters) m")
            } header: {
                Text("Resumen del reporte")
            } footer: {
                Text("Generado a partir de lo que dictaste. Revisa que esté correcto.")
            }

            if !viewModel.isSent {
                Section {
                    Button {
                        Task { await viewModel.send() }
                    } label: {
                        Text("Enviar a Cruz Roja")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isSending)
                    .listRowBackground(Color.brandRed)
                }
            }
        }
        .animation(.default, value: viewModel.isSent)
        .navigationTitle(viewModel.isSent ? "Reporte enviado" : "Revisar reporte")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value.isEmpty ? "—" : value)
    }

    private func trackingStep(_ title: String, _ detail: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                .font(.title3)
                .foregroundStyle(done ? Color.primary : Color.brandRed)
            VStack(alignment: .leading) {
                Text(title).font(.body.weight(done ? .regular : .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    var report = EmergencyReport()
    report.applyDictationSample()
    return NavigationStack { SummaryView(viewModel: AppContainer.preview.makeEmergencyReportViewModel(report: report)) }
}
