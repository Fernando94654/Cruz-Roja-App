import SwiftUI

struct AlertsView: View {
    @State private var viewModel: AlertsViewModel
    @State private var showsNewReport = false

    init(viewModel: AlertsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                if viewModel.hasLoaded {
                    summaryCard
                }

                Section("Alertas oficiales") {
                    scopePicker
                    if viewModel.hasLoaded && viewModel.officialAlerts.isEmpty {
                        Text(viewModel.officialScope == .myArea ? "No hay alertas oficiales en tu zona"
                                                                : "No hay alertas oficiales vigentes en México")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.officialAlerts) { alert in
                        officialAlertRow(alert)
                    }
                }

                Section("Reportes de vecinos") {
                    categoryFilter
                    if viewModel.hasLoaded && viewModel.filteredReports.isEmpty {
                        Text(viewModel.selectedCategory == nil ? "No hay reportes cerca de ti" : "No hay reportes de esta categoría")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.filteredReports) { report in
                        communityReportRow(report)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    Task { await viewModel.toggleFalseFlag(report) }
                                } label: {
                                    Label(report.flaggedByMe ? "Quitar" : "Falso",
                                          systemImage: report.flaggedByMe ? "flag.slash.fill" : "flag.fill")
                                }
                                .tint(report.flaggedByMe ? .gray : .orange)
                            }
                    }
                }
            }
            .navigationTitle("Alertas")
            .task { await viewModel.load() }
            // Se regenera el resumen cuando cambian las alertas o los reportes; la tarea anterior se cancela
            .task(id: viewModel.summaryKey) { await viewModel.summarize() }
            .onDisappear { viewModel.stopSpeech() }
            .refreshable { await viewModel.load() }
            .safeAreaInset(edge: .bottom) {
                Button {
                    viewModel.startNewReport()
                    showsNewReport = true
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
            .sheet(isPresented: $showsNewReport) {
                NewCommunityReportView(viewModel: viewModel)
            }
        }
    }

    // Tarjeta con el resumen generado por la IA y el boton para escucharlo
    private var summaryCard: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(viewModel.summary?.source == .rules ? "Resumen automático" : "Resumen con IA",
                      systemImage: viewModel.summary?.source == .rules ? "text.bubble" : "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.brandRed)
                if let summary = viewModel.summary {
                    Text(summary.text)
                        .font(.body)
                        .opacity(viewModel.isSummarizing ? 0.5 : 1)
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Analizando las alertas de tu zona…")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button {
                        viewModel.toggleSpeech()
                    } label: {
                        Label(viewModel.isSpeaking ? "Detener" : "Escuchar",
                              systemImage: viewModel.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.summary == nil)
                    Spacer()
                    if viewModel.summary?.source == .ai {
                        Text("Generado en tu iPhone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // Selector entre las alertas de la zona del usuario y las de todo Mexico
    private var scopePicker: some View {
        Picker("Mostrar", selection: Binding(
            get: { viewModel.officialScope },
            set: { scope in Task { await viewModel.setOfficialScope(scope) } }
        )) {
            ForEach(OfficialAlertScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    // Aviso de error con opcion de reintentar o cerrarlo
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.subheadline)
                Button("Reintentar") {
                    Task { await viewModel.load() }
                }
                .font(.subheadline.bold())
            }
            Spacer()
            Button {
                viewModel.dismissError()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Cerrar aviso")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 4)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip("Todos", category: nil)
                ForEach(CommunityReportCategory.allCases) { category in
                    categoryChip(category.label, category: category)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func categoryChip(_ title: String, category: CommunityReportCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button(title) {
            viewModel.selectedCategory = category
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.brandRed : Color(.secondarySystemFill), in: Capsule())
        .foregroundStyle(isSelected ? .white : .primary)
        .buttonStyle(.plain)
    }

    private func officialAlertRow(_ alert: OfficialAlert) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.icon)
                .font(.title2)
                .foregroundStyle(Color.brandRed)
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.headline)
                HStack(spacing: 6) {
                    Circle()
                        .fill(alert.severity.color)
                        .frame(width: 10, height: 10)
                    Text(alert.severity.label)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                if let message = alert.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(alert.source) · \(alert.areaName) · \(alert.issuedAt, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func communityReportRow(_ report: CommunityReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(report.title).font(.headline)
            if report.isConfirmed {
                Label("Confirmado", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            Text("\(report.category.label) · confirmado por \(report.confirmations) vecinos · expira en \(report.expiresAt, style: .relative)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if report.flaggedByMe {
                Label("Lo marcaste como falso · desliza para quitarlo", systemImage: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if report.isMine {
                Text("Tu reporte")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    Task { await viewModel.toggleConfirmation(report) }
                } label: {
                    Label(report.confirmedByMe ? "Confirmaste" : "Confirmar",
                          systemImage: report.confirmedByMe ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(report.confirmedByMe ? .green : .primary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AlertsView(viewModel: AppContainer.preview.makeAlertsViewModel())
}
