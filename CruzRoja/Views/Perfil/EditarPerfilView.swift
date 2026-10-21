import SwiftUI

/// Formulario para crear o editar el perfil médico.
/// Trabaja sobre una copia (borrador); solo se guarda al tocar "Guardar".
struct EditarPerfilView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var borrador: PerfilMedico
    @State private var conFecha: Bool
    let viewModel: PerfilViewModel

    init(perfil: PerfilMedico, viewModel: PerfilViewModel) {
        _borrador = State(initialValue: perfil)
        _conFecha = State(initialValue: perfil.fechaNacimiento != nil)
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos personales") {
                    TextField("Nombre completo", text: $borrador.nombre)
                        .textContentType(.name)
                    Toggle("Fecha de nacimiento", isOn: $conFecha.animation())
                    if conFecha {
                        DatePicker(
                            "Fecha",
                            selection: fechaNacimiento,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                Section("Tipo de sangre") {
                    Picker("Tipo de sangre", selection: $borrador.tipoSangre) {
                        ForEach(TipoSangre.allCases) { tipo in
                            Text(tipo.etiqueta).tag(tipo)
                        }
                    }
                }

                ListaEditable(titulo: "Alergias", ejemplo: "Ej. Penicilina", elementos: $borrador.alergias)
                ListaEditable(titulo: "Padecimientos", ejemplo: "Ej. Asma", elementos: $borrador.padecimientos)
                ListaEditable(titulo: "Medicamentos", ejemplo: "Ej. Salbutamol", elementos: $borrador.medicamentos)

                contactos
            }
            .navigationTitle(viewModel.perfil == nil ? "Nuevo perfil" : "Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.guardando {
                        ProgressView()
                    } else {
                        Button("Guardar", action: guardar)
                            .disabled(borrador.nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .alert("No se pudo guardar", isPresented: hayError) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(viewModel.mensajeError ?? "")
            }
            .interactiveDismissDisabled(viewModel.guardando)
        }
    }

    // MARK: - Contactos

    private var contactos: some View {
        Section {
            ForEach($borrador.contactos) { $contacto in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Nombre", text: $contacto.nombre)
                        .textContentType(.name)
                    TextField("Parentesco (ej. Hija)", text: $contacto.parentesco)
                    TextField("Teléfono a 10 dígitos", text: $contacto.telefono)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    if !contacto.telefono.isEmpty && !PerfilMedico.telefonoValido(contacto.telefono) {
                        Text("El teléfono debe tener 10 dígitos.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { borrador.contactos.remove(atOffsets: $0) }

            if borrador.contactos.count < PerfilMedico.maximoContactos {
                Button("Agregar contacto", systemImage: "plus.circle.fill") {
                    withAnimation {
                        borrador.contactos.append(ContactoEmergencia(nombre: "", parentesco: "", telefono: ""))
                    }
                }
            }
        } header: {
            Text("Contactos de emergencia")
        } footer: {
            Text("Hasta \(PerfilMedico.maximoContactos) contactos. Desliza a la izquierda para eliminar.")
        }
    }

    // MARK: - Auxiliares

    /// Une el toggle con la fecha opcional del perfil.
    private var fechaNacimiento: Binding<Date> {
        Binding(
            get: { borrador.fechaNacimiento ?? Self.fechaSugerida },
            set: { borrador.fechaNacimiento = $0 }
        )
    }

    private static var fechaSugerida: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    private var hayError: Binding<Bool> {
        Binding(
            get: { viewModel.mensajeError != nil },
            set: { if !$0 { viewModel.mensajeError = nil } }
        )
    }

    private func guardar() {
        var perfil = borrador
        if !conFecha {
            perfil.fechaNacimiento = nil
        } else if perfil.fechaNacimiento == nil {
            perfil.fechaNacimiento = Self.fechaSugerida
        }
        Task {
            if await viewModel.guardar(perfil) {
                dismiss()
            }
        }
    }
}

/// Sección con una lista de textos que se pueden agregar y borrar
/// (alergias, padecimientos, medicamentos).
struct ListaEditable: View {
    let titulo: String
    let ejemplo: String
    @Binding var elementos: [String]
    @State private var nuevo = ""

    var body: some View {
        Section {
            ForEach(elementos, id: \.self) { elemento in
                Text(elemento)
            }
            .onDelete { elementos.remove(atOffsets: $0) }

            HStack {
                TextField(ejemplo, text: $nuevo)
                    .submitLabel(.done)
                    .onSubmit(agregar)
                Button("Agregar", systemImage: "plus.circle.fill", action: agregar)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .buttonStyle(.borderless)
                    .disabled(nuevo.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text(titulo)
        } footer: {
            if elementos.isEmpty {
                Text("Si no tienes, déjalo vacío.")
            }
        }
    }

    private func agregar() {
        let texto = nuevo.trimmingCharacters(in: .whitespacesAndNewlines)
        nuevo = ""
        guard !texto.isEmpty,
              !elementos.contains(where: { $0.caseInsensitiveCompare(texto) == .orderedSame })
        else { return }
        withAnimation { elementos.append(texto) }
    }
}

#Preview {
    EditarPerfilView(perfil: PerfilMedico(), viewModel: PerfilViewModel())
}
