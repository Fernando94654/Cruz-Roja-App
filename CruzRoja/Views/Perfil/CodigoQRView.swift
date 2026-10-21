import SwiftUI

/// Código QR a pantalla completa para que el paramédico lo escanee fácilmente.
struct CodigoQRView: View {
    let nombre: String
    let texto: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Perfil médico")
                .font(.marca(28))
            Text(nombre)
                .font(.title3)
                .foregroundStyle(.secondary)

            if let imagen = GeneradorQR.imagen(de: texto) {
                Image(uiImage: imagen)
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
    CodigoQRView(nombre: "María López", texto: "CRUZ ROJA · PERFIL MÉDICO\nSangre: O+")
}
