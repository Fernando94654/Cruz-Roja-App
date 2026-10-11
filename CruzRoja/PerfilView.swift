import SwiftUI
import CoreImage.CIFilterBuiltins

struct PerfilView: View {
    @AppStorage("sesion") private var sesion = false
    @AppStorage("correo") private var correo = ""
    @State private var login = demo == "login"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if sesion {
                        HStack(spacing: 14) {
                            avatar
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mi cuenta").font(.headline)
                                Text(correo.isEmpty ? "usuario@correo.com" : correo)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            login = true
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

                Section("Datos médicos") {
                    LabeledContent("Tipo de sangre", value: "O+")
                    LabeledContent("Alergias", value: "Penicilina")
                    LabeledContent("Padecimientos", value: "Asma")
                    LabeledContent("Medicamentos", value: "Salbutamol")
                }

                Section("Contacto de emergencia") {
                    LabeledContent("Hija", value: "81 1234 5678")
                }

                Section {
                    HStack(spacing: 16) {
                        Image(uiImage: codigoQR("perfil-medico:O+;Penicilina;Asma;Salbutamol"))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 96, height: 96)
                        Text("El paramédico escanea el código y ve el perfil completo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Perfil médico")
            .toolbar {
                if sesion {
                    Button("Cerrar sesión") {
                        withAnimation { sesion = false }
                    }
                }
            }
            .sheet(isPresented: $login) {
                LoginView()
            }
        }
    }

    var avatar: some View {
        Image(systemName: "person.fill")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(sesion ? Color.rojo : Color.gray, in: Circle())
    }

    func codigoQR(_ texto: String) -> UIImage {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        guard let salida = filtro.outputImage,
              let img = CIContext().createCGImage(salida, from: salida.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: img)
    }
}

#Preview {
    PerfilView()
}
