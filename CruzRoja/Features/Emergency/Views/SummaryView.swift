import MessageUI
import SwiftUI

/// Report review, sending and SMS to the operator.
struct SummaryView: View {
    let viewModel: EmergencyReportViewModel
    @State private var showsComposer = false
    @State private var copied = false

    private var report: EmergencyReport { viewModel.report }

    var body: some View {
        List {
            if viewModel.isSent {
                Section("Seguimiento") {
                    trackingStep("Reporte recibido", "Guardado en Cruz Roja", done: true)
                    trackingStep("Ubicación enviada", "SMS al operador con enlace", done: true)
                    trackingStep("Unidad en camino", "Ambulancia 214 · ≈ 8 min", done: false)
                }

                Section("Enlace para el operador") {
                    Text(viewModel.shareURL ?? "")
                        .foregroundStyle(Color.brandRed)
                        .textSelection(.enabled)
                    HStack {
                        if MFMessageComposeViewController.canSendText() {
                            Button("Enviar SMS de nuevo") { showsComposer = true }
                        }
                        Button(copied ? "Copiado" : "Copiar enlace") {
                            UIPasteboard.general.string = viewModel.shareURL
                            copied = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                }

                Section {
                    NavigationLink(value: EmergencyRoute.firstAid) {
                        Label("Ver instrucciones de primeros auxilios", systemImage: "bandage")
                    }
                }
            }

            Section("Resumen para el operador") {
                Text(viewModel.summary)
                    .fontWeight(.medium)
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
                row("Ubicación", viewModel.location?.address ?? "Ubicación no disponible")
            } header: {
                Text("Detalle del reporte")
            } footer: {
                Text("Generado a partir de lo que escribiste o dictaste. Revisa que esté correcto.")
            }

            if !viewModel.isSent {
                Section {
                    Button {
                        Task {
                            // The simulator can't send SMS; the link stays on screen to copy
                            if await viewModel.send(), MFMessageComposeViewController.canSendText() {
                                showsComposer = true
                            }
                        }
                    } label: {
                        Text(viewModel.isSending ? "Enviando…" : "Enviar a Cruz Roja")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isSending || viewModel.location == nil)
                    .listRowBackground(Color.brandRed)
                    if viewModel.location == nil {
                        Text("Vuelve al reporte y activa la ubicación del teléfono para poder enviarlo.")
                            .font(.footnote)
                            .foregroundStyle(Color.brandRed)
                    }
                }
            }
        }
        .animation(.default, value: viewModel.isSent)
        .navigationTitle(viewModel.isSent ? "Reporte enviado" : "Revisar reporte")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsComposer) {
            MessageComposer(recipient: viewModel.operatorPhone, body: viewModel.smsBody)
                .ignoresSafeArea()
        }
        .alert("No se pudo enviar", isPresented: hasError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
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

// Native SMS composer prefilled with the summary and the operator link
struct MessageComposer: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = [recipient]
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}

#Preview {
    let container = AppContainer.preview
    NavigationStack { SummaryView(viewModel: container.makeEmergencyReportViewModel(report: container.demoReport())) }
}
