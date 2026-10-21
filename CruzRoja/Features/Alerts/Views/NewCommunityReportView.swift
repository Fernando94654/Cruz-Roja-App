import SwiftUI

struct NewCommunityReportView: View {
    let viewModel: AlertsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var category: CommunityReportCategory = .flood
    @State private var title = ""
    @State private var isPublishing = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $category) {
                    ForEach(CommunityReportCategory.allCases) { category in
                        Text(category.label).tag(category)
                    }
                }
                TextField("¿Qué pasó? Ej. Calle inundada", text: $title, axis: .vertical)
                Label("Se usará tu ubicación actual", systemImage: "location.fill")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Nuevo reporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicar", action: publish)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isPublishing)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func publish() {
        isPublishing = true
        Task {
            if await viewModel.publish(category: category, title: title) { dismiss() }
            isPublishing = false
        }
    }
}

#Preview {
    NewCommunityReportView(viewModel: AppContainer.preview.makeAlertsViewModel())
}
