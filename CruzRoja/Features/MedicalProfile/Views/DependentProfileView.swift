import SwiftUI

// Value pushed on the profile tab's NavigationStack to open a family member's profile
struct DependentRoute: Hashable {
    let id: UUID
}

// "Familiares" section in the profile tab: list of family members plus "Agregar familiar"
struct DependentsSection: View {
    let viewModel: DependentProfilesViewModel
    let onAdd: () -> Void

    var body: some View {
        Section {
            switch viewModel.state {
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }

            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Reintentar") {
                        Task { await viewModel.load() }
                    }
                }

            case .ready:
                if viewModel.dependents.isEmpty {
                    Text("Agrega el perfil médico de quien cuidas, aunque no tenga la app, para reportar por esa persona con su información.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.dependents) { dependent in
                    NavigationLink(value: DependentRoute(id: dependent.id)) {
                        DependentRow(dependent: dependent)
                    }
                }
                if viewModel.canAddMore {
                    Button("Agregar familiar", systemImage: "person.badge.plus", action: onAdd)
                }
            }
        } header: {
            Text("Familiares")
        } footer: {
            if viewModel.isShowingCachedCopy {
                Text("Sin conexión. Se muestra la última copia guardada.")
            }
        }
    }
}

struct DependentRow: View {
    let dependent: DependentProfile

    var body: some View {
        HStack(spacing: 12) {
            Text(String(dependent.fullName.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.brandRed, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(dependent.fullName)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        var parts = [dependent.relationship]
        if dependent.profile.bloodType != .unknown {
            parts.append("Sangre \(dependent.profile.bloodType.label)")
        }
        if !dependent.profile.allergies.isEmpty {
            parts.append("Alergias: \(dependent.profile.allergies.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}

// Full profile of one family member, with its own QR code
struct DependentProfileView: View {
    let dependentID: UUID
    let viewModel: DependentProfilesViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("qrIncludesContacts") private var qrIncludesContacts = false
    @State private var isEditing = false
    @State private var showsQR = false
    @State private var confirmsDelete = false

    var body: some View {
        Group {
            if let dependent = viewModel.dependent(id: dependentID) {
                List {
                    MedicalProfileDetailSections(profile: dependent.profile, relationship: dependent.relationship)
                    MedicalProfileQRSection(profile: dependent.profile, includesContacts: $qrIncludesContacts) {
                        showsQR = true
                    }
                    Section {
                        Button("Eliminar familiar", role: .destructive) { confirmsDelete = true }
                    }
                }
                .navigationTitle(dependent.fullName)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Editar") { isEditing = true }
                    }
                }
                .sheet(isPresented: $isEditing) {
                    EditDependentView(dependent: dependent, viewModel: viewModel)
                }
                .fullScreenCover(isPresented: $showsQR) {
                    QRCodeView(name: dependent.fullName, text: dependent.profile.qrText(includeContacts: qrIncludesContacts))
                }
                .confirmationDialog(
                    "¿Eliminar el perfil de \(dependent.fullName)?",
                    isPresented: $confirmsDelete,
                    titleVisibility: .visible
                ) {
                    Button("Eliminar", role: .destructive) {
                        Task {
                            if await viewModel.delete(dependent) { dismiss() }
                        }
                    }
                } message: {
                    Text("Se borrarán sus datos médicos y contactos.")
                }
            } else {
                ContentUnavailableView("Familiar no encontrado", systemImage: "person.crop.circle.badge.questionmark")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Algo salió mal", isPresented: hasError) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !isEditing },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// Create or edit a family member's profile; nothing is stored until "Guardar"
struct EditDependentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DependentProfile
    @State private var hasDateOfBirth: Bool
    private let isNew: Bool
    let viewModel: DependentProfilesViewModel

    init(dependent: DependentProfile? = nil, viewModel: DependentProfilesViewModel) {
        _draft = State(initialValue: dependent ?? DependentProfile())
        _hasDateOfBirth = State(initialValue: dependent?.profile.dateOfBirth != nil)
        isNew = dependent == nil
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                MedicalProfileFormSections(
                    draft: $draft.profile,
                    hasDateOfBirth: $hasDateOfBirth,
                    relationship: $draft.relationship
                )
            }
            .navigationTitle(isNew ? "Nuevo familiar" : "Editar familiar")
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
                            .disabled(!canSave)
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

    private var canSave: Bool {
        !draft.profile.fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.relationship.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func save() {
        var dependent = draft
        dependent.profile = MedicalProfileFormSections.applyingDateChoice(to: draft.profile, hasDateOfBirth: hasDateOfBirth)
        Task {
            if await viewModel.save(dependent) { dismiss() }
        }
    }
}

#Preview("Familiar") {
    let viewModel = AppContainer.preview.makeDependentProfilesViewModel()
    NavigationStack {
        DependentProfileView(dependentID: DependentProfile.sample.id, viewModel: viewModel)
    }
    .task { await viewModel.load() }
}

#Preview("Nuevo familiar") {
    EditDependentView(viewModel: AppContainer.preview.makeDependentProfilesViewModel())
}
