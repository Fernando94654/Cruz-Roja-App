import SwiftUI

// Form fields shared by the user's own profile and the profiles of family members.
// Pass `relationship` to show the "Parentesco" field (dependents only).
struct MedicalProfileFormSections: View {
    @Binding var draft: MedicalProfile
    @Binding var hasDateOfBirth: Bool
    var relationship: Binding<String>? = nil

    var body: some View {
        Section("Datos personales") {
            TextField("Nombre completo", text: $draft.fullName)
                .textContentType(.name)
            if let relationship {
                TextField("Parentesco (ej. Mamá, Hijo, Abuela)", text: relationship)
            }
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

    static var suggestedDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    // Applies the date toggle before saving: off clears the date, on without picking uses the suggestion
    static func applyingDateChoice(to profile: MedicalProfile, hasDateOfBirth: Bool) -> MedicalProfile {
        var copy = profile
        if !hasDateOfBirth {
            copy.dateOfBirth = nil
        } else if copy.dateOfBirth == nil {
            copy.dateOfBirth = suggestedDate
        }
        return copy
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
                Text("Si no tiene, déjalo vacío.")
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
