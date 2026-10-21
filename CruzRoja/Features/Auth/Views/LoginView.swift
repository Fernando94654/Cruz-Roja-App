import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AuthViewModel
    @State private var showsPassword = false
    @FocusState private var field: Field?

    enum Field { case email, password }

    init(viewModel: AuthViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.brandRed, in: RoundedRectangle(cornerRadius: 16))

                    Text("Inicia sesión")
                        .font(.brand(34))
                    Text("Guarda tu perfil médico para que los paramédicos sepan cómo atenderte.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                VStack(spacing: 14) {
                    inputField(icon: "envelope") {
                        TextField("Correo electrónico", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($field, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { field = .password }
                    }

                    inputField(icon: "lock") {
                        Group {
                            if showsPassword {
                                TextField("Contraseña", text: $viewModel.password)
                            } else {
                                SecureField("Contraseña", text: $viewModel.password)
                            }
                        }
                        .textContentType(.password)
                        .focused($field, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)

                        Button {
                            showsPassword.toggle()
                        } label: {
                            Image(systemName: showsPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.gray)
                        }
                    }

                    Button("¿Olvidaste tu contraseña?") {}
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Button(action: signIn) {
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Iniciar sesión").font(.brand(17))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brandRed, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.isLoading)

                HStack {
                    Rectangle().frame(height: 1)
                    Text("o").font(.subheadline)
                    Rectangle().frame(height: 1)
                }
                .foregroundStyle(.gray.opacity(0.4))

                // Placeholder until Sign in with Apple is wired
                Button(action: signIn) {
                    Label("Continuar con Apple", systemImage: "apple.logo")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.black, in: RoundedRectangle(cornerRadius: 14))
                }

                HStack(spacing: 4) {
                    Text("¿No tienes cuenta?").foregroundStyle(.secondary)
                    Button("Regístrate") {}.fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)

                Text("Cruz Roja Mexicana · Delegación Nuevo León")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.gray)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6), in: Circle())
            }
            .padding()
        }
    }

    private func inputField<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
    }

    private func signIn() {
        field = nil
        Task {
            if await viewModel.signIn() { dismiss() }
        }
    }
}

#Preview {
    LoginView(viewModel: AppContainer.preview.makeAuthViewModel())
}
