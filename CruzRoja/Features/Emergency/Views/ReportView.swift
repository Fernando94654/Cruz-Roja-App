import SwiftUI

struct ReportView: View {
    @Bindable var viewModel: EmergencyReportViewModel

    var body: some View {
        ScrollViewReader { scroll in
            Form {
                Section("¿Para quién?") {
                    Picker("¿Para quién?", selection: $viewModel.report.reportingFor) {
                        ForEach(ReportingFor.allCases, id: \.self) {
                            Text($0.label)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if let name = viewModel.report.patientName {
                        Label("Paciente: \(name)", systemImage: "person.text.rectangle")
                            .font(.subheadline)
                    }
                }

                Section {
                    TextField(viewModel.isPreparingDictation || isListening ? "" : "Ej. Mi abuela se cayó en la casa y está confundida",
                              text: $viewModel.report.description, axis: .vertical)
                        .lineLimit(3...6)

                    Button {
                        Task { await viewModel.toggleDictation() }
                    } label: {
                        if viewModel.isPreparingDictation {
                            Label("Preparando micrófono…", systemImage: "mic.fill")
                        } else {
                            Label(isListening ? "Detener dictado" : "Dictar", systemImage: isListening ? "stop.fill" : "mic.fill")
                                .foregroundStyle(isListening ? Color.brandRed : Color.primary)
                        }
                    }
                    .disabled(viewModel.isFilling || viewModel.isPreparingDictation)

                    Button {
                        Task { await viewModel.fillFromDescription() }
                    } label: {
                        HStack {
                            if viewModel.isFilling {
                                ProgressView()
                                Text("Pensando…")
                            } else {
                                Label("Llenar con IA", systemImage: "sparkles")
                            }
                        }
                        .foregroundStyle(Color.brandRed)
                    }
                    .disabled(viewModel.isFilling || isListening || viewModel.report.description.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let message = viewModel.fillMessage {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if viewModel.aiSummary != nil {
                                Text(viewModel.summary)
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                } header: {
                    Text("¿Qué está pasando?")
                } footer: {
                    Text("Escribe o dicta y llenamos el reporte por ti. Revisa los campos antes de enviar.")
                }

                Section("Incidente") {
                    textField("Motivo", $viewModel.report.reason)
                    Stepper("Lesionados: \(viewModel.report.injuredCount)", value: $viewModel.report.injuredCount, in: 1...20)
                    textField("Lesión principal", $viewModel.report.injury)
                    textField("Lugar", $viewModel.report.place)
                }

                Section("Ubicación") {
                    Label {
                        VStack(alignment: .leading) {
                            Text(viewModel.location?.address ?? "Ubicación no disponible")
                            Text(locationStatus)
                                .font(.caption)
                                .foregroundStyle(viewModel.location == nil && !viewModel.isLocating ? Color.brandRed : .secondary)
                        }
                    } icon: {
                        Image(systemName: "location.fill")
                    }
                    textField("Referencia", $viewModel.report.reference)
                    if viewModel.location == nil && !viewModel.isLocating {
                        Button("Reintentar ubicación") {
                            Task { await viewModel.locate() }
                        }
                    }
                }

                Section("Estado del paciente") {
                    vitalSign("Estado mental", $viewModel.report.mentalState, EmergencyReport.mentalStates)
                        .id("vitals")
                    vitalSign("Respiración", $viewModel.report.breathing, EmergencyReport.breathingOptions)
                    vitalSign("Color de piel", $viewModel.report.skin, EmergencyReport.skinColors)
                }
            }
            .animation(.default, value: viewModel.report)
            .onAppear {
                if DemoMode.isActive("vitals") { scroll.scrollTo("vitals", anchor: .top) }
            }
            .task { await viewModel.locate() }
            .task { viewModel.prewarmAI() }
            .onDisappear { viewModel.dictation.stop() }
            .alert("Aviso", isPresented: hasError) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .navigationTitle("Reporte")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            NavigationLink(value: EmergencyRoute.summary) {
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

    private var isListening: Bool { viewModel.dictation.isListening }

    private var locationStatus: String {
        if viewModel.isLocating { return "Obteniendo ubicación…" }
        guard let location = viewModel.location else { return "Activa la ubicación del teléfono para enviar el reporte" }
        return "Automática · ±\(location.accuracyMeters) m"
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func textField(_ title: String, _ text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func vitalSign(_ title: String, _ value: Binding<String>, _ options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker(title, selection: value) {
                ForEach(options, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { ReportView(viewModel: AppContainer.preview.makeEmergencyReportViewModel()) }
}
