import SwiftUI

enum FamilyRoute: Hashable {
    case member(UUID)
}

struct FamilyView: View {
    let container: AppContainer
    @State private var viewModel: FamilyViewModel
    @State private var reportViewModel: EmergencyReportViewModel
    @State private var path = NavigationPath()
    @State private var showsInvite = false
    @State private var showsLogin = false

    // Demo mode works without the server, so it doesn't need a session
    private var canSeeFamily: Bool {
        container.session.isSignedIn || DemoMode.isActive("family")
    }

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeFamilyViewModel())
        _reportViewModel = State(initialValue: container.makeEmergencyReportViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Familia")
                .toolbar {
                    if canSeeFamily && viewModel.hasLoaded && viewModel.loadError == nil {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Agregar familiar", systemImage: "person.badge.plus") { showsInvite = true }
                        }
                    }
                }
                .task(id: canSeeFamily) {
                    if canSeeFamily { await viewModel.load() }
                }
                // Checks again while someone hasn't answered "¿Estás bien?"
                .task(id: viewModel.isWaitingForAnswers) {
                    while viewModel.isWaitingForAnswers && !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(3))
                        if Task.isCancelled { return }
                        await viewModel.load()
                    }
                }
                .onChange(of: viewModel.needsSignIn) { _, needsSignIn in
                    if needsSignIn { container.session.signOut() }
                }
                .sheet(isPresented: $showsLogin) {
                    LoginView(viewModel: container.makeAuthViewModel())
                }
                .sheet(isPresented: $showsInvite) {
                    InviteMemberView(viewModel: viewModel)
                }
                .navigationDestination(for: FamilyRoute.self) { route in
                    switch route {
                    case .member(let id):
                        FamilyMemberView(viewModel: viewModel, memberID: id, onReport: report)
                    }
                }
                .emergencyDestinations(report: reportViewModel, container: container)
        }
        // On the stack so they also show over a member's screen
        .overlay(alignment: .bottom) { noticeBanner }
        .task(id: viewModel.notice) {
            guard viewModel.notice != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation { viewModel.notice = nil }
        }
        .alert("No se pudo completar", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !canSeeFamily {
            ContentUnavailableView {
                Label("Inicia sesión para ver a tu familia", systemImage: "person.2")
            } description: {
                Text("Solo tú y tu familia pueden ver cómo están y dónde están.")
            } actions: {
                Button("Iniciar sesión") { showsLogin = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandRed)
            }
        } else if !viewModel.hasLoaded {
            ProgressView()
        } else if let error = viewModel.loadError {
            ContentUnavailableView {
                Label("Sin conexión", systemImage: "wifi.slash")
            } description: {
                Text(error)
            } actions: {
                Button("Reintentar") { Task { await viewModel.load() } }
                    .buttonStyle(.bordered)
            }
        } else {
            familyList
        }
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if let notice = viewModel.notice {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { withAnimation { viewModel.notice = nil } }
        }
    }

    private var familyList: some View {
        let family = viewModel.family
        return List {
            // Someone in the family needs help: the first thing you see, with what to do
            ForEach(viewModel.membersNeedingHelp) { member in
                Section { helpRow(member) }
            }

            if let request = family.wellbeingRequest {
                Section { wellbeingRow(request) }
            }

            if !family.members.isEmpty {
                FamilyMapSection(viewModel: viewModel, onOpen: open, onReport: report)
            }

            if !family.receivedInvitations.isEmpty {
                Section("Invitaciones") {
                    ForEach(family.receivedInvitations) { receivedRow($0) }
                }
            }

            Section("Mi familia") {
                if family.members.isEmpty {
                    Text("Agrega a tu familia para saber cómo están en una emergencia.")
                        .foregroundStyle(.secondary)
                }
                ForEach(family.members) { member in
                    NavigationLink(value: FamilyRoute.member(member.id)) {
                        MemberRow(member: member)
                    }
                }
                Button("Agregar familiar", systemImage: "plus") { showsInvite = true }
                    .tint(Color.brandRed)
            }

            if !family.sentInvitations.isEmpty {
                Section {
                    ForEach(family.sentInvitations) { sentRow($0) }
                } header: {
                    Text("Esperando respuesta")
                } footer: {
                    Text("Aparecerán en tu familia cuando acepten la invitación.")
                }
            }

            Section {
                Toggle("Compartir mi ubicación", isOn: Binding(
                    get: { family.sharesLocation },
                    set: { value in Task { await viewModel.setSharesLocation(value) } }
                ))
            } footer: {
                Text(family.sharesLocation
                     ? "Tu familia puede ver dónde estás."
                     : "Tu familia no ve dónde estás. Si reportas una emergencia, sí se comparte.")
            }
        }
        .disabled(viewModel.isBusy)
        .refreshable { await viewModel.load() }
        .animation(.default, value: family)
    }

    private func open(_ member: FamilyMember) {
        path.append(FamilyRoute.member(member.id))
    }

    // The report starts with the member's name and their location, where the ambulance has to go
    private func report(_ member: FamilyMember) {
        let (report, location) = viewModel.report(for: member)
        startReport(report, location: location)
    }

    private func startReport(_ report: EmergencyReport, location: EmergencyLocation = .current) {
        reportViewModel = container.makeEmergencyReportViewModel(report: report, location: location)
        path.append(EmergencyRoute.report)
    }

    private func helpRow(_ member: FamilyMember) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { open(member) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandRed)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(member.firstName) necesita ayuda")
                            .font(.headline)
                            .foregroundStyle(Color.brandRed)
                        Text([member.updatedAt.formatted(.relative(presentation: .named)).capitalizedFirst,
                              viewModel.distance(to: member)].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            MemberActions(member: member, viewModel: viewModel, onReport: report)
        }
        .padding(.vertical, 4)
    }

    private func wellbeingRow(_ request: WellbeingRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandRed)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(request.fromName) quiere saber si estás bien")
                        .font(.headline)
                    Text(request.reason ?? "Enviado \(request.sentAt.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button {
                    Task { await viewModel.answer(.ok) }
                } label: {
                    Text("Estoy bien").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                // Asking for help warns the family and goes straight to the report
                Button {
                    Task {
                        if await viewModel.answer(.needHelp) { startReport(EmergencyReport()) }
                    }
                } label: {
                    Text("Necesito ayuda").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandRed)
            }
            .controlSize(.large)
        }
        .padding(.vertical, 4)
    }

    private func receivedRow(_ invitation: FamilyInvitation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(invitation.fromName ?? "Alguien") te invitó a su familia")
                    .font(.headline)
                Text("Podrá ver cómo estás y dónde estás.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button {
                    Task { await viewModel.respond(to: invitation, accept: false) }
                } label: {
                    Text("Rechazar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                Button {
                    Task { await viewModel.respond(to: invitation, accept: true) }
                } label: {
                    Text("Aceptar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandRed)
            }
        }
        .padding(.vertical, 4)
    }

    private func sentRow(_ invitation: FamilyInvitation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.name)
                Text("Enviada \(invitation.sentAt, format: .relative(presentation: .named))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancelar") {
                Task { await viewModel.cancel(invitation) }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pieces shared by the family screens

struct MemberRow: View {
    let member: FamilyMember

    var body: some View {
        HStack(spacing: 12) {
            MemberAvatar(member: member, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body.weight(.medium))
                if let relationship = member.relationship {
                    Text(relationship)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            StatusLabel(status: member.status)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

struct MemberAvatar: View {
    let member: FamilyMember
    let size: CGFloat

    var body: some View {
        Text(member.initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(member.status == .needHelp ? Color.brandRed : .secondary)
            .frame(width: size, height: size)
            .background(member.status == .needHelp ? Color.brandRed.opacity(0.12) : Color(.systemGray5),
                        in: Circle())
            .accessibilityHidden(true)
    }
}

// Colored dot plus text, so it doesn't depend on color alone
struct StatusLabel: View {
    let status: MemberStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.text)
                .foregroundStyle(status == .needHelp ? Color.brandRed : .secondary)
                .fontWeight(status == .needHelp ? .semibold : .regular)
        }
    }
}

extension MemberStatus {
    var text: String {
        switch self {
        case .ok: "Está bien"
        case .needHelp: "Necesita ayuda"
        case .waiting: "Sin responder"
        case .unknown: "Sin noticias"
        }
    }

    var color: Color {
        switch self {
        case .ok: .green
        case .needHelp: .brandRed
        case .waiting: .orange
        case .unknown: Color(.systemGray3)
        }
    }
}

extension String {
    // "hace 2 minutos" -> "Hace 2 minutos"
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

#Preview {
    FamilyView(container: .preview)
}
