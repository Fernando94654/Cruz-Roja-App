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
                Section("Datos personales") {
                    TextField("Nombre completo", text: $draft.fullName)
                        .textContentType(.name)
                    Toggle("Fecha de nacimiento", isOn: $hasDateOfBirth.animation())
                    if hasDateOfBirth {
                        DatePicker("Fecha", selection: dateOfBirth, in: ...Date(), displayedComponents: .date)
                    }
                }

                Section("Tipo de sangre") {
                    Picker("Tipo de sangre", selection: $draft.bloodType) {
                        ForEach(BloodType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                }

                EditableListSection(title: "Alergias", placeholder: "Ej. Penicilina", items: $draft.allergies)
                EditableListSection(title: "Padecimientos", placeholder: "Ej. Asma", items: $draft.conditions)
                EditableListSection(title: "Medicamentos", placeholder: "Ej. Salbutamol", items: $draft.medications)

                contacts
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

    private var contacts: some View {
        Section {
            ForEach($draft.contacts) { $contact in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Nombre", text: $contact.name)
                        .textContentType(.name)
                    TextField("Parentesco (ej. Hija)", text: $contact.relationship)
                    TextField("Teléfono a 10 dígitos", text: $contact.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    if !contact.phone.isEmpty && !MedicalProfile.isValidPhone(contact.phone) {
                        Text("El teléfono debe tener 10 dígitos.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { draft.contacts.remove(atOffsets: $0) }

            if draft.contacts.count < MedicalProfile.maxContacts {
                Button("Agregar contacto", systemImage: "plus.circle.fill") {
                    withAnimation {
                        draft.contacts.append(EmergencyContact(name: "", relationship: "", phone: ""))
                    }
                }
            }
        } header: {
            Text("Contactos de emergencia")
        } footer: {
            Text("Hasta \(MedicalProfile.maxContacts) contactos. Desliza a la izquierda para eliminar.")
        }
    }

    // Binds the toggle to the optional date of birth
    private var dateOfBirth: Binding<Date> {
        Binding(
            get: { draft.dateOfBirth ?? Self.suggestedDate },
            set: { draft.dateOfBirth = $0 }
        )
    }

    private static var suggestedDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func save() {
        var profile = draft
        if !hasDateOfBirth {
            profile.dateOfBirth = nil
        } else if profile.dateOfBirth == nil {
            profile.dateOfBirth = Self.suggestedDate
        }
        Task {
            if await viewModel.save(profile) { dismiss() }
        }
    }
}

// List of texts that can be added and removed (allergies, conditions, medications)
struct EditableListSection: View {
    let title: String
    let placeholder: String
    @Binding var items: [String]
    @State private var newItem = ""

    var body: some View {
        Section {
            ForEach(items, id: \.self) { item in
                Text(item)
            }
            .onDelete { items.remove(atOffsets: $0) }

            HStack {
                TextField(placeholder, text: $newItem)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Agregar", systemImage: "plus.circle.fill", action: add)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .buttonStyle(.borderless)
                    .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text(title)
        } footer: {
            if items.isEmpty {
                Text("Si no tienes, déjalo vacío.")
            }
        }
    }

    private func add() {
        let text = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        newItem = ""
        guard !text.isEmpty,
              !items.contains(where: { $0.caseInsensitiveCompare(text) == .orderedSame })
        else { return }
        withAnimation { items.append(text) }
    }
}

#Preview {
    EditMedicalProfileView(profile: .sample, viewModel: AppContainer.preview.makeMedicalProfileViewModel())
}
