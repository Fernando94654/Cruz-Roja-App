import SwiftUI

struct MedicalProfileView: View {
    let container: AppContainer
    @State private var viewModel: MedicalProfileViewModel
    @State private var dependents: DependentProfilesViewModel
    // Contact phones stay out of the QR unless the user opts in
    @AppStorage("qrIncludesContacts") private var qrIncludesContacts = false
    @State private var showsLogin = DemoMode.isActive("login")
    @State private var isEditing = false
    @State private var showsQR = false
    @State private var isAddingDependent = false

    private var session: SessionStore { container.session }

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeMedicalProfileViewModel())
        _dependents = State(initialValue: container.makeDependentProfilesViewModel())
    }

    var body: some View {
        NavigationStack {
            List {
                Section { account }
                content
                DependentsSection(viewModel: dependents) { isAddingDependent = true }
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
            .task { await loadAll() }
            .refreshable { await loadAll() }
            .navigationDestination(for: DependentRoute.self) { route in
                DependentProfileView(dependentID: route.id, viewModel: dependents)
            }
            .sheet(isPresented: $showsLogin) {
                LoginView(viewModel: container.makeAuthViewModel())
            }
            .sheet(isPresented: $isEditing) {
                EditMedicalProfileView(profile: viewModel.profile ?? MedicalProfile(), viewModel: viewModel)
            }
            .sheet(isPresented: $isAddingDependent) {
                EditDependentView(viewModel: dependents)
            }
            .fullScreenCover(isPresented: $showsQR) {
                if let profile = viewModel.profile {
                    QRCodeView(name: profile.fullName, text: profile.qrText(includeContacts: qrIncludesContacts))
                }
            }
        }
    }

    // Own profile and family members load in parallel
    private func loadAll() async {
        async let profile: Void = viewModel.load()
        async let family: Void = dependents.load()
        _ = await (profile, family)
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

        MedicalProfileDetailSections(profile: profile)
        MedicalProfileQRSection(profile: profile, includesContacts: $qrIncludesContacts) {
            showsQR = true
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
