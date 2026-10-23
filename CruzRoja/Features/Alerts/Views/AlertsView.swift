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
                    categoryFilter
                    if viewModel.filteredReports.isEmpty {
                        Text("No hay reportes de esta categoría")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.filteredReports) { report in
                        communityReportRow(report)
                            .swipeActions(edge: .trailing) {
                                Button {
                                    Task { await viewModel.flagAsFalse(report) }
                                } label: {
                                    Label("Falso", systemImage: "flag.fill")
                                }
                                .tint(.orange)
                                .disabled(report.flaggedByMe)
                            }
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
