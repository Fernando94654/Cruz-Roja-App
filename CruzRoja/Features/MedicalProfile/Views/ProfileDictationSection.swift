import SwiftUI

// "Dictar mis datos": la persona habla y la IA acomoda los datos en el formulario; ella revisa y guarda
struct ProfileDictationSection: View {
    @Binding var draft: MedicalProfile
    // Se enciende cuando la IA llena la fecha de nacimiento, para que se vea en el formulario
    @Binding var hasDateOfBirth: Bool
    @State private var model = ProfileDictationViewModel(dictation: SpeechDictation(), extractor: FallbackProfileExtractor())

    var body: some View {
        Section {
            Text("Di lo que recuerdes: edad, tipo de sangre, alergias, padecimientos, medicamentos y contactos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Ej. Tengo 70 años, soy diabético y tomo metformina", text: $model.transcript, axis: .vertical)
                .lineLimit(2...6)
                .disabled(model.isListening)

            Button {
                Task { await toggle() }
            } label: {
                if model.isPreparing {
                    Label("Preparando micrófono…", systemImage: "mic.fill")
                } else if model.isListening {
                    Label("Terminar y llenar", systemImage: "stop.fill")
                        .foregroundStyle(Color.brandRed)
                } else {
                    Label("Empezar a hablar", systemImage: "mic.fill")
                }
            }
            .disabled(model.isPreparing || model.isFilling)

            if model.canFill {
                Button("Llenar con IA", systemImage: "sparkles") {
                    Task { await fill() }
                }
            }

            if model.isFilling {
                ProgressView("Acomodando tus datos…")
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Dictar mis datos")
        } footer: {
            Text("Se procesa en tu iPhone, sin enviar tu voz a internet.")
        }
        .onDisappear { model.stop() }

        // Lo que agregó la IA; la persona puede corregir cualquier campo antes de guardar
        if !model.added.isEmpty || model.ageNote != nil || model.message != nil {
            Section {
                ForEach(model.added, id: \.self) { line in
                    Label(line, systemImage: "sparkles")
                }
                if let note = model.ageNote {
                    Label(note, systemImage: "calendar.badge.exclamationmark")
                }
            } header: {
                Text("Sugerido: revisa antes de guardar")
            } footer: {
                if let message = model.message {
                    Text(message)
                }
            }
        }
    }

    // Si está escuchando, termina y llena; si no, empieza a escuchar
    private func toggle() async {
        if model.isListening {
            await fill()
        } else {
            await model.start()
        }
    }

    private func fill() async {
        draft = await model.fill(draft)
        if draft.dateOfBirth != nil { hasDateOfBirth = true }
    }
}
