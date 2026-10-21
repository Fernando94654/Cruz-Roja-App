import SwiftUI

// Full-screen QR so the paramedic can scan it easily
struct QRCodeView: View {
    let name: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Perfil médico")
                .font(.brand(28))
            Text(name)
                .font(.title3)
                .foregroundStyle(.secondary)

            if let image = QRCodeGenerator.image(for: text) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Código QR del perfil médico")
            } else {
                Text("El perfil tiene demasiada información para un solo código. Quita algunos elementos.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Text("Muestra este código al paramédico.\nSe lee con la cámara, sin internet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Cerrar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
        .padding(24)
    }
}

#Preview {
    QRCodeView(name: "María López", text: MedicalProfile.sample.qrText(includeContacts: false))
}
