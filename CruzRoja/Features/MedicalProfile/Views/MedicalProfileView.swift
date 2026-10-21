import SwiftUI

struct MedicalProfileView: View {
    let container: AppContainer
    @State private var viewModel: MedicalProfileViewModel
    // Contact phones stay out of the QR unless the user opts in
    @AppStorage("qrIncludesContacts") private var qrIncludesContacts = false
    @State private var showsLogin = DemoMode.isActive("login")
    @State private var isEditing = false
    @State private var showsQR = false

    private var session: SessionStore { container.session }

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeMedicalProfileViewModel())
    }

    var body: some View {
        NavigationStack {
            List {
                Section { account }
                content
            }
            .navigationTitle("Perfil médico")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if session.isSignedIn {
                        Button("Cerrar sesión") {
                            withAnimation { session.signOut() }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.profile != nil {
                        Button("Editar") { isEditing = true }
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showsLogin) {
                LoginView(viewModel: container.makeAuthViewModel())
            }
            .sheet(isPresented: $isEditing) {
                EditMedicalProfileView(profile: viewModel.profile ?? MedicalProfile(), viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showsQR) {
                if let profile = viewModel.profile {
                    QRCodeView(name: profile.fullName, text: profile.qrText(includeContacts: qrIncludesContacts))
                }
            }
        }
    }

    // MARK: - Content by state

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            Section {
                HStack {
                    Spacer()
                    ProgressView("Cargando perfil…")
                    Spacer()
                }
                .padding(.vertical)
            }

        case .empty:
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.brandRed)
                    Text("Completa tu perfil médico")
                        .font(.headline)
                    Text("Los paramédicos sabrán tu tipo de sangre, alergias y medicamentos antes de llegar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Completar perfil") { isEditing = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brandRed)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

        case .failed(let message):
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Button("Reintentar") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

        case .ready:
            if let profile = viewModel.profile {
                sections(for: profile)
            }
        }
    }

    @ViewBuilder
    private func sections(for profile: MedicalProfile) -> some View {
        if viewModel.isShowingCachedCopy {
            Section {
                Label("Sin conexión. Se muestra la última copia guardada.", systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Datos personales") {
            LabeledContent("Nombre", value: profile.fullName)
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

        Section {
            Button {
                showsQR = true
            } label: {
                HStack(spacing: 16) {
                    if let image = QRCodeGenerator.image(for: profile.qrText(includeContacts: qrIncludesContacts)) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 96, height: 96)
                    }
                    Text("El paramédico escanea el código y ve tu perfil. Toca para agrandarlo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Toggle("Incluir contactos en el código", isOn: $qrIncludesContacts)
        } footer: {
            Text("El código funciona sin internet. Cualquier persona que lo escanee puede leerlo.")
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var account: some View {
        if session.isSignedIn {
            HStack(spacing: 14) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mi cuenta").font(.headline)
                    Text(session.email.isEmpty ? "usuario@correo.com" : session.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Button {
                showsLogin = true
            } label: {
                HStack(spacing: 14) {
                    avatar
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inicia sesión o regístrate")
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Text("Respalda tu perfil y compártelo con tu familia")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
        }
    }

    private var avatar: some View {
        Image(systemName: "person.fill")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(session.isSignedIn ? Color.brandRed : Color.gray, in: Circle())
    }
}

#Preview {
    MedicalProfileView(container: .preview)
}
