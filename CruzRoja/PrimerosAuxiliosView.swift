import SwiftUI
import AVFoundation

let pasosHemorragia = [
    "Protege tus manos con guantes o una bolsa de plástico.",
    "Presiona con firmeza sobre la herida con una tela limpia. No la retires.",
    "Si la tela se empapa, pon otra encima y sigue presionando.",
    "Mantén a la persona acostada y abrigada hasta que llegue la ambulancia.",
]

struct PrimerosAuxiliosView: View {
    @State private var paso = demo == "auxilios" ? 1 : 0
    @State private var voz = AVSpeechSynthesizer()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Paso \(paso + 1) de \(pasosHemorragia.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(paso + 1), total: Double(pasosHemorragia.count))
                    .tint(Color.rojo)
            }

            Spacer()

            Text(pasosHemorragia[paso])
                .font(.marca(32))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                hablar()
            } label: {
                Label("Escuchar", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.bordered)
            .tint(.primary)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    withAnimation { paso -= 1 }
                } label: {
                    Text("Anterior").frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(paso == 0)

                Button {
                    withAnimation { paso += 1 }
                } label: {
                    Text("Siguiente").frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(paso == pasosHemorragia.count - 1)
            }
            .tint(.black)

            Text("Basado en protocolos de Cruz Roja")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .navigationTitle("Hemorragia")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: paso) { voz.stopSpeaking(at: .immediate) }
    }

    func hablar() {
        voz.stopSpeaking(at: .immediate)
        let texto = AVSpeechUtterance(string: pasosHemorragia[paso])
        texto.voice = AVSpeechSynthesisVoice(language: "es-MX")
        voz.speak(texto)
    }
}

#Preview {
    NavigationStack { PrimerosAuxiliosView() }
}
