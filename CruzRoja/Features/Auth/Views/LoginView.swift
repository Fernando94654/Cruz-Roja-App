import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sesion") private var sesion = false
    @AppStorage("correo") private var correoGuardado = ""
    @State private var correo = ""
    @State private var contrasena = ""
    @State private var verContrasena = false
    @State private var cargando = false
    @FocusState private var campo: Campo?

    enum Campo { case correo, contrasena }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.rojo, in: RoundedRectangle(cornerRadius: 16))

                    Text("Inicia sesión")
                        .font(.marca(34))
                    Text("Guarda tu perfil médico para que los paramédicos sepan cómo atenderte.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                VStack(spacing: 14) {
                    entrada(icono: "envelope") {
                        TextField("Correo electrónico", text: $correo)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($campo, equals: .correo)
                            .submitLabel(.next)
                            .onSubmit { campo = .contrasena }
                    }

                    entrada(icono: "lock") {
                        Group {
                            if verContrasena {
                                TextField("Contraseña", text: $contrasena)
                            } else {
                                SecureField("Contraseña", text: $contrasena)
                            }
                        }
                        .textContentType(.password)
                        .focused($campo, equals: .contrasena)
                        .submitLabel(.go)
                        .onSubmit(entrar)

                        Button {
                            verContrasena.toggle()
                        } label: {
                            Image(systemName: verContrasena ? "eye.slash" : "eye")
                                .foregroundStyle(.gray)
                        }
                    }

                    Button("¿Olvidaste tu contraseña?") {}
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Button(action: entrar) {
                    ZStack {
                        if cargando {
                            ProgressView().tint(.white)
                        } else {
                            Text("Iniciar sesión").font(.marca(17))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.rojo, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(cargando)

                HStack {
                    Rectangle().frame(height: 1)
                    Text("o").font(.subheadline)
                    Rectangle().frame(height: 1)
                }
                .foregroundStyle(.gray.opacity(0.4))

                // de mentira, solo para que se vea la opción
                Button(action: entrar) {
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

    func entrada<Contenido: View>(icono: String, @ViewBuilder contenido: () -> Contenido) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            contenido()
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
    }

    // no hay backend, cualquier dato entra
    func entrar() {
        campo = nil
        cargando = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            correoGuardado = correo.isEmpty ? "usuario@correo.com" : correo
            withAnimation { sesion = true }
            cargando = false
            dismiss()
        }
    }
}

#Preview {
    LoginView()
}
