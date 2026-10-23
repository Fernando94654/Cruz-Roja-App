import SwiftUI

struct InviteMemberView: View {
    let viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var usesEmail = false
    @State private var contact = ""
    @State private var relationship = FamilyMember.relationships[0]
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                        .textContentType(.name)
                    Picker("Parentesco", selection: $relationship) {
                        ForEach(FamilyMember.relationships, id: \.self) { Text($0) }
                    }
                }

                Section {
                    Picker("Enviar por", selection: $usesEmail) {
                        Text("Celular").tag(false)
                        Text("Correo").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .onChange(of: usesEmail) { contact = "" }

                    TextField(usesEmail ? "nombre@correo.com" : "Celular a 10 dígitos", text: $contact)
                        .keyboardType(usesEmail ? .emailAddress : .phonePad)
                        .textContentType(usesEmail ? .emailAddress : .telephoneNumber)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if let message {
                        Text(message).foregroundStyle(Color.brandRed)
                    } else {
                        Text("Le llegará una invitación. Solo verá cómo estás y dónde estás si la acepta.")
                    }
                }
            }
            .navigationTitle("Agregar familiar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") { Task { await send() } }
                        .disabled(viewModel.isBusy)
                }
            }
        }
    }

    private func send() async {
        message = await viewModel.invite(name: name, contact: contact, relationship: relationship)
        if message == nil { dismiss() }
    }
}

#Preview {
    InviteMemberView(viewModel: AppContainer.preview.makeFamilyViewModel())
}
