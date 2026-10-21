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
                Section("Alertas oficiales") {
                    ForEach(viewModel.officialAlerts) { alert in
                        officialAlertRow(alert)
                    }
                }

                Section("Reportes de vecinos") {
                    ForEach(viewModel.activeReports) { report in
                        communityReportRow(report)
                    }
                }
            }
            .navigationTitle("Alertas")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .safeAreaInset(edge: .bottom) {
                Button {
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

    private func officialAlertRow(_ alert: OfficialAlert) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alert.icon)
                .font(.title2)
                .foregroundStyle(Color.brandRed)
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.headline)
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
            Text("\(report.category.label) · confirmado por \(report.confirmations) vecinos · expira en \(report.expiresAt, style: .relative)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(report.confirmedByMe ? "Confirmado" : "Confirmar") {
                Task { await viewModel.confirm(report) }
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .disabled(report.confirmedByMe)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AlertsView(viewModel: AppContainer.preview.makeAlertsViewModel())
}
