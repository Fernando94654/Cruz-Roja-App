import SwiftUI

struct FirstAidView: View {
    @State private var viewModel: FirstAidViewModel
    @FocusState private var isInputFocused: Bool

    // Keeps the view model alive across view updates
    init(viewModel: FirstAidViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // Chat with the messages on top and the input bar at the bottom
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if viewModel.messages.isEmpty {
                            intro
                        }
                        ForEach(viewModel.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if viewModel.isThinking {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Buscando en el material de Cruz Roja…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                            .id("thinking")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages) {
                    withAnimation { proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom) }
                }
                .onChange(of: viewModel.isThinking) {
                    if viewModel.isThinking { withAnimation { proxy.scrollTo("thinking", anchor: .bottom) } }
                }
            }

            inputBar
        }
        .navigationTitle("Primeros auxilios")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.messages.isEmpty {
                Button("Nueva") { viewModel.reset() }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // Shown before the first message: explanation, suggestions and emergency types
    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Describe la emergencia")
                .font(.brand(30))
            Text("Escribe o habla. El asistente busca en el material de Cruz Roja y te guía paso a paso por voz.")
                .foregroundStyle(.secondary)

            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                Button {
                    send(suggestion)
                } label: {
                    Text(suggestion)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Text("O elige el tipo de emergencia")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.guides) { guide in
                        NavigationLink(value: EmergencyRoute.guide(guide)) {
                            Label(guide.title, systemImage: guide.icon)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.gray.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Basado en protocolos de Cruz Roja. No sustituye un curso certificado.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // Draws a user message or an assistant answer card
    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        switch message {
        case .user(_, let text):
            HStack {
                Spacer(minLength: 40)
                Text(text)
                    .padding(12)
                    .foregroundStyle(.white)
                    .background(Color.brandRed, in: RoundedRectangle(cornerRadius: 16))
            }
        case .assistant(let answer):
            AnswerCard(answer: answer, viewModel: viewModel)
        }
    }

    // Text field plus the button that sends, starts dictation or stops it and sends
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(viewModel.isListening ? "Escuchando…" : "¿Qué está pasando?", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                .onSubmit { send(viewModel.draft) }

            Button {
                if viewModel.hasDraft && !viewModel.isListening {
                    send(viewModel.draft)
                } else {
                    isInputFocused = false
                    Task { await viewModel.toggleDictation() }
                }
            } label: {
                Image(systemName: viewModel.isListening ? "waveform" : viewModel.hasDraft ? "arrow.up" : "mic.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(viewModel.isListening ? Color.black : Color.brandRed, in: Circle())
                    .symbolEffect(.variableColor.iterative, isActive: viewModel.isListening)
            }
            .disabled(viewModel.isPreparingDictation || viewModel.isThinking)
            .accessibilityLabel(viewModel.isListening ? "Terminar y enviar" : viewModel.hasDraft ? "Enviar" : "Dictar")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            if let error = viewModel.dictationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .offset(y: -18)
            }
        }
        .background(.bar)
    }

    // Hides the keyboard and sends the text to the assistant
    private func send(_ text: String) {
        isInputFocused = false
        Task { await viewModel.send(text) }
    }
}

struct AnswerCard: View {
    let answer: AssistantAnswer
    let viewModel: FirstAidViewModel

    private var isSpeaking: Bool { viewModel.speech.isSpeaking }

    // Answer text, the guide to start by voice and its related video
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let guide = answer.guide {
                Label(guide.title, systemImage: guide.icon)
                    .font(.headline)
                    .foregroundStyle(Color.brandRed)
            }

            Text(answer.text)

            HStack {
                Button {
                    viewModel.toggleSpeech(for: answer)
                } label: {
                    Label(isSpeaking ? "Detener" : "Escuchar", systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                if let guide = answer.guide {
                    NavigationLink(value: EmergencyRoute.guide(guide)) {
                        Label("Iniciar guía por voz", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                }
            }
            if let guide = answer.guide {
                RelatedLessonLink(guideID: guide.id, lessons: viewModel.lessons, stopSpeech: viewModel.stop)
            }
        }
        .padding()
        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let container = AppContainer.preview
    GuidesRefreshed(container: container) {
        NavigationStack {
            FirstAidView(viewModel: container.makeFirstAidViewModel())
                .emergencyDestinations(report: container.makeEmergencyReportViewModel(), container: container)
        }
    }
}
