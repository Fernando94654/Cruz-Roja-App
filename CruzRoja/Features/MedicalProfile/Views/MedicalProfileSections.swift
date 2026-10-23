import SwiftUI

// Read-only sections of a medical profile, shared by "Mi perfil" and family members' profiles
struct MedicalProfileDetailSections: View {
    let profile: MedicalProfile
    var relationship: String? = nil

    var body: some View {
        Section("Datos personales") {
            LabeledContent("Nombre", value: profile.fullName)
            if let relationship, !relationship.isEmpty {
                LabeledContent("Parentesco", value: relationship)
            }
            if let age = profile.age() {
                LabeledContent("Edad", value: "\(age) años")
            }
        }

        Section("Datos médicos") {
            LabeledContent("Tipo de sangre", value: profile.bloodType.label)
            LabeledContent("Alergias", value: MedicalProfile.text(for: profile.allergies))
            LabeledContent("Padecimientos", value: MedicalProfile.text(for: profile.conditions))
            LabeledContent("Medicamentos", value: MedicalProfile.text(for: profile.medications))
        }

        Section("Contactos de emergencia") {
            if profile.contacts.isEmpty {
                Text("Sin contactos registrados")
                    .foregroundStyle(.secondary)
            }
            ForEach(profile.contacts) { contact in
                LabeledContent {
                    if let url = URL(string: "tel:\(MedicalProfile.digitsOnly(contact.phone))") {
                        Link(contact.formattedPhone, destination: url)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                        Text(contact.relationship)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// QR thumbnail plus the privacy toggle for contacts.
// The parent presents the full-screen QR (presentations inside List rows are unreliable).
struct MedicalProfileQRSection: View {
    let profile: MedicalProfile
    @Binding var includesContacts: Bool
    let onShowFullScreen: () -> Void

    var body: some View {
        Section {
            Button(action: onShowFullScreen) {
                HStack(spacing: 16) {
                    if let image = QRCodeGenerator.image(for: profile.qrText(includeContacts: includesContacts)) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 96, height: 96)
                    }
                    Text("El paramédico escanea el código y ve el perfil. Toca para agrandarlo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Toggle("Incluir contactos en el código", isOn: $includesContacts)
        } footer: {
            Text("El código funciona sin internet. Cualquier persona que lo escanee puede leerlo.")
        }
    }
}
