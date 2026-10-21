import SwiftUI

/// Pestaña "Perfil": muestra el perfil médico guardado en el API y su código QR.
struct PerfilView: View {
    @AppStorage("sesion") private var sesion = false
    @AppStorage("correo") private var correo = ""
    /// Por privacidad, los teléfonos de los contactos no van en el QR a menos que el usuario lo active.
    @AppStorage("qrIncluyeContactos") private var qrIncluyeContactos = false

    @State private var viewModel = PerfilViewModel()
    @State private var login = demo == "login"
    @State private var editando = false
    @State private var mostrarQR = false

    var body: some View {
        NavigationStack {
            List {
                Section { cuenta }
                contenido
            }
            .navigationTitle("Perfil médico")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if sesion {
                        Button("Cerrar sesión") {
                            withAnimation { sesion = false }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.perfil != nil {
                        Button("Editar") { editando = true }
                    }
                }
            }
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .sheet(isPresented: $login) {
                LoginView()
            }
            .sheet(isPresented: $editando) {
                EditarPerfilView(perfil: viewModel.perfil ?? PerfilMedico(), viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $mostrarQR) {
                if let perfil = viewModel.perfil {
                    CodigoQRView(
                        nombre: perfil.nombre,
                        texto: perfil.textoQR(incluirContactos: qrIncluyeContactos)
                    )
                }
            }
        }
    }

    // MARK: - Contenido según el estado

    @ViewBuilder
    private var contenido: some View {
        switch viewModel.estado {
        case .cargando:
            Section {
                HStack {
                    Spacer()
                    ProgressView("Cargando perfil…")
                    Spacer()
                }
                .padding(.vertical)
            }

        case .vacio:
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.rojo)
                    Text("Completa tu perfil médico")
                        .font(.headline)
                    Text("Los paramédicos sabrán tu tipo de sangre, alergias y medicamentos antes de llegar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Completar perfil") { editando = true }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.rojo)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

        case .error(let mensaje):
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(mensaje)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Button("Reintentar") {
                        Task { await viewModel.cargar() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

        case .listo:
            if let perfil = viewModel.perfil {
                secciones(de: perfil)
            }
        }
    }

    @ViewBuilder
    private func secciones(de perfil: PerfilMedico) -> some View {
        if viewModel.usandoCopiaLocal {
            Section {
                Label("Sin conexión. Se muestra la última copia guardada.", systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Datos personales") {
            LabeledContent("Nombre", value: perfil.nombre)
            if let edad = perfil.edad() {
                LabeledContent("Edad", value: "\(edad) años")
            }
        }

        Section("Datos médicos") {
            LabeledContent("Tipo de sangre", value: perfil.tipoSangre.etiqueta)
            LabeledContent("Alergias", value: PerfilMedico.texto(de: perfil.alergias))
            LabeledContent("Padecimientos", value: PerfilMedico.texto(de: perfil.padecimientos))
            LabeledContent("Medicamentos", value: PerfilMedico.texto(de: perfil.medicamentos))
        }

        Section("Contactos de emergencia") {
            if perfil.contactos.isEmpty {
                Text("Sin contactos registrados")
                    .foregroundStyle(.secondary)
            }
            ForEach(perfil.contactos) { contacto in
                LabeledContent {
                    if let url = URL(string: "tel:\(PerfilMedico.soloDigitos(contacto.telefono))") {
                        Link(contacto.telefonoFormateado, destination: url)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contacto.nombre)
                        Text(contacto.parentesco)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        Section {
            Button {
                mostrarQR = true
            } label: {
                HStack(spacing: 16) {
                    if let imagen = GeneradorQR.imagen(de: perfil.textoQR(incluirContactos: qrIncluyeContactos)) {
                        Image(uiImage: imagen)
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

            Toggle("Incluir contactos en el código", isOn: $qrIncluyeContactos)
        } footer: {
            Text("El código funciona sin internet. Cualquier persona que lo escanee puede leerlo.")
        }
    }

    // MARK: - Cuenta (igual que en el mockup)

    @ViewBuilder
    private var cuenta: some View {
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

    private var avatar: some View {
        Image(systemName: "person.fill")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(sesion ? Color.rojo : Color.gray, in: Circle())
    }
}

#Preview {
    PerfilView()
}
