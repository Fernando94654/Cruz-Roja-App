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
                        Label("Perfil médico de \(name) cargado", systemImage: "person.text.rectangle")
                            .font(.subheadline)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.dictate() }
                    } label: {
                        Label(viewModel.isListening ? "Escuchando…" : "Dictar", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(viewModel.isListening)
                } footer: {
                    Text("Describe lo que pasa y llenamos el reporte por ti.")
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
                            Text(viewModel.location.address)
                            Text("Automática · ±\(viewModel.location.accuracyMeters) m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "location.fill")
                    }
                    textField("Referencia", $viewModel.report.reference)
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
