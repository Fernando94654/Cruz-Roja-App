import SwiftUI

struct AprendeView: View {
    @State private var ruta: [Leccion] = demo == "leccion" ? [lecciones[0]] : []

    var body: some View {
        NavigationStack(path: $ruta) {
            List(lecciones) { leccion in
                NavigationLink(value: leccion) {
                    HStack(spacing: 14) {
                        Miniatura()
                            .frame(width: 110, height: 66)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(leccion.titulo).font(.headline)
                            Text("Video · \(leccion.duracion)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Aprende")
            .navigationDestination(for: Leccion.self) { LeccionView(leccion: $0) }
        }
    }
}

struct Miniatura: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.gray.opacity(0.25))
            .overlay {
                Image(systemName: "play.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.35), in: Circle())
            }
    }
}

struct LeccionView: View {
    let leccion: Leccion
    @State private var avance = 0.0
    private let voz = Voz.compartida

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // reproductor de mentira
                Miniatura()
                    .aspectRatio(16/9, contentMode: .fit)

                VStack(spacing: 4) {
                    Slider(value: $avance)
                        .tint(Color.rojo)
                    HStack {
                        Text("0:00")
                        Spacer()
                        Text(leccion.duracion)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                Text(leccion.titulo).font(.marca(28))
                Text(leccion.descripcion)
                    .foregroundStyle(.secondary)

                ForEach(Array(leccion.pasos.enumerated()), id: \.offset) { i, paso in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.rojo, in: Circle())
                        Text(paso)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    if voz.hablando {
                        voz.callar()
                    } else {
                        voz.decir(([leccion.titulo] + leccion.pasos).joined(separator: ". "))
                    }
                } label: {
                    Label(voz.hablando ? "Detener" : "Escuchar lección",
                          systemImage: voz.hablando ? "stop.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                Divider()

                Label("Lección certificada por instructores de Cruz Roja", systemImage: "checkmark.seal")
                    .font(.subheadline)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { voz.callar() }
    }
}

#Preview {
    AprendeView()
}
