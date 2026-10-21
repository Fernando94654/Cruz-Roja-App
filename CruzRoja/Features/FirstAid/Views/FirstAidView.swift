import SwiftUI

enum Mensaje: Identifiable, Hashable {
    case usuario(UUID, String)
    case asistente(Respuesta)

    var id: UUID {
        switch self {
        case .usuario(let id, _): id
        case .asistente(let r): r.id
        }
    }
}

struct PrimerosAuxiliosView: View {
    @State private var texto = ""
    @State private var mensajes: [Mensaje] = demo == "auxilios"
        ? [.usuario(UUID(), "Me corté y sangra mucho"), .asistente(Asistente().buscar("sangra"))]
        : []
    @State private var pensando = false
    @State private var escuchando = false
    @FocusState private var enfocado: Bool

    private let voz = Voz.compartida
    private let ambulancia = Ambulancia.actual
    private let asistente = Asistente()
    private let sugerencias = [
        "Mi papá no respira y no responde",
        "Un niño se está atragantando",
        "Me corté y sangra mucho",
        "Se quemó con aceite",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BarraAmbulancia(ambulancia: ambulancia)

                        if mensajes.isEmpty {
                            inicio
                        }
                        ForEach(mensajes) { m in
                            burbuja(m).id(m.id)
                        }
                        if pensando {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Buscando en el material de Cruz Roja…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                            .id("pensando")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: mensajes) {
                    withAnimation { proxy.scrollTo(mensajes.last?.id, anchor: .bottom) }
                }
                .onChange(of: pensando) {
                    if pensando { withAnimation { proxy.scrollTo("pensando", anchor: .bottom) } }
                }
            }

            barraEntrada
        }
        .navigationTitle("Primeros auxilios")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !mensajes.isEmpty {
                Button("Nueva") {
                    voz.callar()
                    mensajes.removeAll()
                }
            }
        }
        .onAppear { ambulancia.solicitar() }
        .onDisappear { voz.callar() }
    }

    var inicio: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Describe la emergencia")
                .font(.marca(30))
            Text("Escribe o habla. El asistente busca en el material de Cruz Roja y te guía paso a paso por voz.")
                .foregroundStyle(.secondary)

            Label("RAG sobre manuales de Cruz Roja · demo", systemImage: "books.vertical.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.rojo)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.rojo.opacity(0.1), in: Capsule())

            ForEach(sugerencias, id: \.self) { s in
                Button {
                    enviar(s)
                } label: {
                    Text(s)
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
                    ForEach(emergencias) { e in
                        NavigationLink(value: Pantalla.guia(e)) {
                            Label(e.titulo, systemImage: e.icono)
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

    @ViewBuilder
    func burbuja(_ m: Mensaje) -> some View {
        switch m {
        case .usuario(_, let t):
            HStack {
                Spacer(minLength: 40)
                Text(t)
                    .padding(12)
                    .foregroundStyle(.white)
                    .background(Color.rojo, in: RoundedRectangle(cornerRadius: 16))
            }
        case .asistente(let r):
            TarjetaRespuesta(respuesta: r, voz: voz)
        }
    }

    var barraEntrada: some View {
        HStack(spacing: 10) {
            TextField(escuchando ? "Escuchando…" : "¿Qué está pasando?", text: $texto, axis: .vertical)
                .lineLimit(1...4)
                .focused($enfocado)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                .onSubmit { enviar(texto) }

            Button {
                if texto.trimmingCharacters(in: .whitespaces).isEmpty { dictar() } else { enviar(texto) }
            } label: {
                Image(systemName: !texto.trimmingCharacters(in: .whitespaces).isEmpty ? "arrow.up" : escuchando ? "waveform" : "mic.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(escuchando ? Color.black : Color.rojo, in: Circle())
                    .symbolEffect(.variableColor.iterative, isActive: escuchando)
            }
            .disabled(escuchando || pensando)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // texto fijo, no hay reconocimiento de voz real
    func dictar() {
        voz.callar()
        enfocado = false
        escuchando = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            escuchando = false
            enviar("Mi abuela se desmayó y está mareada")
        }
    }

    func enviar(_ t: String) {
        let pregunta = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pregunta.isEmpty, !pensando else { return }
        texto = ""
        enfocado = false
        mensajes.append(.usuario(UUID(), pregunta))
        pensando = true
        Task {
            let r = await asistente.responder(pregunta)
            pensando = false
            mensajes.append(.asistente(r))
            voz.decir(r.texto)
        }
    }
}

struct TarjetaRespuesta: View {
    let respuesta: Respuesta
    let voz: Voz

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let e = respuesta.emergencia {
                Label(e.titulo, systemImage: e.icono)
                    .font(.headline)
                    .foregroundStyle(Color.rojo)
            }

            Text(respuesta.texto)

            VStack(alignment: .leading, spacing: 6) {
                Text("Fuentes consultadas")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(respuesta.fuentes) { f in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(Color.rojo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(f.documento) · pág. \(f.pagina)")
                                .font(.caption.weight(.semibold))
                            Text("“\(f.fragmento)”")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button {
                    if voz.hablando { voz.callar() } else { voz.decir(respuesta.texto) }
                } label: {
                    Label(voz.hablando ? "Detener" : "Escuchar", systemImage: voz.hablando ? "stop.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                if let e = respuesta.emergencia {
                    NavigationLink(value: Pantalla.guia(e)) {
                        Label("Iniciar guía por voz", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
                }
            }
        }
        .padding()
        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        PrimerosAuxiliosView()
            .pantallas(Reporte())
    }
}
