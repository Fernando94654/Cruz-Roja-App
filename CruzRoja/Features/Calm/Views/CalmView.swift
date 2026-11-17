import SwiftUI

// Pantalla completa para calmarse: que pasa, tecnica elegida por la IA, calificacion y plan
struct CalmView: View {
    @State private var viewModel: CalmViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // Sin ViewModel usa la IA, la voz y el microfono reales
    init(viewModel: CalmViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? CalmViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.concerns.isEmpty {
                    safetyBanner
                }
                switch viewModel.stage {
                case .intake: intake
                case .breathing: breathing
                case .talking: conversation
                case .checkIn: checkIn
                case .done: done
                }
                crisisLineFooter
            }
            .navigationTitle("Calma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { close() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.toggleVoice()
                    } label: {
                        Image(systemName: viewModel.isVoiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .accessibilityLabel(viewModel.isVoiceOn ? "Silenciar voz" : "Activar voz")
                }
            }
            .onAppear { viewModel.onAppear() }
            .task(id: viewModel.breathingRun) { await viewModel.runBreathing() }
            .onDisappear { viewModel.stop() }
        }
    }

    // MARK: Inicio

    // Primero se pregunta que pasa, para que la IA elija la tecnica; tambien se puede empezar a respirar ya
    private var intake: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "wind")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandRed)
            Text("¿Qué está pasando?")
                .font(.title2.bold())
            Text("Cuéntame con tus palabras qué sientes o qué pasó. Así elijo el ejercicio que más te puede ayudar.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if viewModel.isAssessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Entendiendo lo que me cuentas…")
                        .foregroundStyle(.secondary)
                }
            }
            if let error = viewModel.dictationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            Spacer()
            Button("Solo quiero respirar") { viewModel.skipIntake() }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandRed)
                .disabled(viewModel.isAssessing)
            inputBar(placeholder: "Ej. Mañana tengo examen y siento el corazón muy rápido") {
                await viewModel.submitIntake()
            }
            .disabled(viewModel.isAssessing)
        }
    }

    // MARK: Respiracion

    private var breathing: some View {
        VStack(spacing: 28) {
            if let message = viewModel.assessment?.message {
                assessmentCaption(message)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.brandRed.opacity(0.12))
                Circle()
                    .fill(Color.brandRed.opacity(0.85))
                    .scaleEffect(viewModel.phase == .exhale ? 0.45 : 1)
                    .animation(.easeInOut(duration: viewModel.phaseSeconds), value: viewModel.breathCount)
                Text(viewModel.phase.label)
                    .font(.brand(30))
                    .foregroundStyle(.white)
            }
            .frame(width: 260, height: 260)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(viewModel.phase.label), ciclo \(viewModel.cycle) de \(viewModel.pattern.cycles)")

            VStack(spacing: 6) {
                Text("Ciclo \(viewModel.cycle) de \(viewModel.pattern.cycles)")
                    .font(.headline)
                Text("Inhala 4 segundos, sostén 4 y exhala 6. Puedes cerrar los ojos y seguir la vibración.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Button("Pasar a hablar") { viewModel.startTalking() }
                .buttonStyle(.bordered)
                .padding(.bottom, 12)
        }
    }

    // MARK: Conversacion

    private var conversation: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if viewModel.isReplying {
                            HStack {
                                ProgressView()
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("typing")
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    withAnimation { proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom) }
                }
            }

            // Siempre se puede terminar o volver a respirar; al acabar los pasos se resalta Terminar
            HStack {
                Button("Respirar otra vez") { viewModel.breatheAgain() }
                    .buttonStyle(.bordered)
                if viewModel.hasFinishedSteps {
                    Button("Terminar") { viewModel.finish() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brandRed)
                } else {
                    Button("Ya me siento mejor") { viewModel.finish() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 8)
            if let error = viewModel.dictationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            inputBar(placeholder: "Escribe o dicta") { await viewModel.send() }
        }
    }

    // Lo que entendio la IA y la tecnica que eligio
    private func assessmentCaption(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(viewModel.technique.title, systemImage: viewModel.assessment?.source == .ai ? "sparkles" : "wind")
                .font(.caption.bold())
                .foregroundStyle(Color.brandRed)
            Text(message)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding([.horizontal, .top])
    }

    private func bubble(_ message: CalmMessage) -> some View {
        let isCoach = message.role == .coach
        return HStack {
            if !isCoach { Spacer(minLength: 40) }
            Text(message.text)
                .padding(12)
                .background(isCoach ? Color(.secondarySystemBackground) : Color.brandRed,
                            in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(isCoach ? Color.primary : Color.white)
            if isCoach { Spacer(minLength: 40) }
        }
    }

    private func inputBar(placeholder: String, onSend: @escaping () async -> Void) -> some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.toggleListening() }
            } label: {
                Image(systemName: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(viewModel.isListening ? Color.brandRed : .secondary)
            }
            .accessibilityLabel(viewModel.isListening ? "Dejar de dictar" : "Dictar")

            TextField(viewModel.isListening ? "Te escucho…" : placeholder, text: $viewModel.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .submitLabel(.send)
                .onSubmit { Task { await onSend() } }

            Button {
                Task { await onSend() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.brandRed)
            }
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isReplying)
            .accessibilityLabel("Enviar")
        }
        .padding()
    }

    // MARK: Calificacion

    private var checkIn: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("¿Qué tan intensa es tu ansiedad ahora?")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("1 es tranquilo y 10 es muy intensa")
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(1...10, id: \.self) { value in
                    Button("\(value)") { Task { await viewModel.saveCheckIn(value) } }
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var done: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brandRed)
                    .padding(.top, 24)
                Text("Gracias por tomarte este momento")
                    .font(.title3.bold())
                if let rating = viewModel.lastRating {
                    if let start = viewModel.assessment?.intensity, start > rating {
                        Text("Empezaste en \(start) y ahora estás en \(rating). Bajó \(start - rating) puntos.")
                            .foregroundStyle(.secondary)
                    }
                    if rating >= 8 {
                        Text("Si la ansiedad sigue muy alta, habla con alguien de confianza o con la Línea de la Vida.")
                            .multilineTextAlignment(.center)
                    }
                }
                planCard
                if !viewModel.previousRatings.isEmpty {
                    Text("Tus veces anteriores: \(viewModel.previousRatings.map(String.init).joined(separator: " → "))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("La próxima vez puedes decir: \"Oye Siri, ayúdame a calmarme con CruzRoja\".")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Cerrar") { close() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandRed)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
    }

    // Plan para la proxima vez que escribe la IA con lo que paso en la sesion
    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tu plan para la próxima vez", systemImage: viewModel.plan?.fromAI == true ? "sparkles" : "list.bullet.clipboard")
                .font(.headline)
                .foregroundStyle(Color.brandRed)
            if let plan = viewModel.plan {
                planRow("Lo que lo detonó", plan.trigger)
                planRow("Lo que te ayudó", plan.helped)
                planRow("Para la próxima vez", plan.nextTime)
                if let pattern = plan.pattern {
                    planRow("Lo que notamos", pattern)
                }
            } else if viewModel.isPlanning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Preparando tu plan…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func planRow(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(text)
        }
    }

    // MARK: Seguridad

    private var safetyBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.concerns.contains(.medical) {
                callButton("Llamar al 911", number: CalmSafety.emergencyNumber, icon: "phone.fill")
            }
            if viewModel.concerns.contains(.selfHarm) {
                callButton("Línea de la Vida · \(CalmSafety.crisisLineLabel)", number: CalmSafety.crisisLineNumber, icon: "heart.text.square.fill")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.brandRed.opacity(0.1))
    }

    private func callButton(_ title: String, number: String, icon: String) -> some View {
        Button {
            if let url = URL(string: "tel://\(number)") { openURL(url) }
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.brandRed)
    }

    // Siempre visible: la app no sustituye la ayuda profesional
    private var crisisLineFooter: some View {
        Button {
            if let url = URL(string: "tel://\(CalmSafety.crisisLineNumber)") { openURL(url) }
        } label: {
            Text("Esto no sustituye la ayuda profesional. Línea de la Vida: \(CalmSafety.crisisLineLabel), 24 horas")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func close() {
        viewModel.stop()
        dismiss()
    }
}

#Preview {
    CalmView(viewModel: CalmViewModel(companion: ScriptedCalmCompanion(), speech: SilentSpeech(),
                                      dictation: SilentDictation(), haptics: SilentBreathHaptics(),
                                      store: InMemoryCalmHistory()))
}
