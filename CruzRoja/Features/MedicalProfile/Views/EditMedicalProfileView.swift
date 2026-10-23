import SwiftUI

// Edits a draft copy; nothing is stored until "Guardar"
struct EditMedicalProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MedicalProfile
    @State private var hasDateOfBirth: Bool
    let viewModel: MedicalProfileViewModel

    init(profile: MedicalProfile, viewModel: MedicalProfileViewModel) {
        _draft = State(initialValue: profile)
        _hasDateOfBirth = State(initialValue: profile.dateOfBirth != nil)
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                MedicalProfileFormSections(draft: $draft, hasDateOfBirth: $hasDateOfBirth)
            }
            .navigationTitle(viewModel.profile == nil ? "Nuevo perfil" : "Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar", action: save)
                            .disabled(draft.fullName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .alert("No se pudo guardar", isPresented: hasError) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .interactiveDismissDisabled(viewModel.isSaving)
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func save() {
        let profile = MedicalProfileFormSections.applyingDateChoice(to: draft, hasDateOfBirth: hasDateOfBirth)
        Task {
            if await viewModel.save(profile) { dismiss() }
        }
    }
}

#Preview {
    EditMedicalProfileView(profile: .sample, viewModel: AppContainer.preview.makeMedicalProfileViewModel())
}
