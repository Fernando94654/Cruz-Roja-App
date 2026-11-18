import SwiftUI

/// Simple mode home: a few huge, high-contrast buttons with large text instead of the tab bar.
struct SimpleHomeView: View {
    let container: AppContainer
    @AppStorage(SimpleMode.storageKey) private var isSimpleMode = false
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var profile: MedicalProfile?
    @State private var showsReport = false
    @State private var showsQR = false
    @State private var confirmsExit = false
    @State private var taps = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Enlace Vital")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                ForEach(SimpleAction.actions(for: profile), id: \.self) { action in
                    actionButton(action)
                }

                Button("Salir del modo sencillo") { confirmsExit = true }
                    .font(.body)
                    .tint(.secondary)
                    .padding(.top, 24)
            }
            .padding()
        }
        // Never smaller than XXXL, and still larger if the user picked an accessibility size
        .dynamicTypeSize(max(typeSize, .xxxLarge))
        .sensoryFeedback(.impact(weight: .heavy), trigger: taps)
        .onAppear { profile = container.cachedMedicalProfile() }
        .fullScreenCover(isPresented: $showsReport) { reportScreen }
        .fullScreenCover(isPresented: $showsQR) {
            if let profile {
                QRCodeView(name: profile.fullName, text: profile.qrText(includeContacts: true))
            }
        }
        .alert("¿Salir del modo sencillo?", isPresented: $confirmsExit) {
            Button("Cancelar", role: .cancel) {}
            Button("Salir") { isSimpleMode = false }
        } message: {
            Text("Volverás a ver todas las pestañas de la app.")
        }
    }

    private func actionButton(_ action: SimpleAction) -> some View {
        Button {
            taps += 1
            perform(action)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: action.systemImage)
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text(action.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(action.isEmergency ? Color.white : Color(.systemBackground))
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .background(action.isEmergency ? Color.brandRed : Color.primary, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.hint)
    }

    private func perform(_ action: SimpleAction) {
        switch action {
        case .report:
            showsReport = true
        case .showMedicalQR:
            showsQR = true
        case .call911, .callContact:
            if let url = action.phoneURL { openURL(url) }
        }
    }

    // Same report flow as the Emergencia tab, but a tap starts it instead of a 3-second hold
    private var reportScreen: some View {
        EmergencyView(container: container, requiresHold: false)
            .safeAreaInset(edge: .bottom) {
                Button {
                    showsReport = false
                } label: {
                    Text("Cerrar")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .padding(.horizontal)
                .background(.bar)
            }
            .dynamicTypeSize(max(typeSize, .xxxLarge))
    }
}

#Preview {
    SimpleHomeView(container: .preview)
}
