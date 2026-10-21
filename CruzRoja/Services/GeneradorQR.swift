import CoreImage.CIFilterBuiltins
import UIKit

enum GeneradorQR {
    /// Genera la imagen del código QR para un texto.
    /// Regresa `nil` si el texto es demasiado largo para caber en un QR.
    static func imagen(de texto: String, escala: CGFloat = 10) -> UIImage? {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"  // tolera ~15 % del código dañado o sucio

        guard let salida = filtro.outputImage else { return nil }
        let grande = salida.transformed(by: CGAffineTransform(scaleX: escala, y: escala))
        guard let imagen = CIContext().createCGImage(grande, from: grande.extent) else { return nil }
        return UIImage(cgImage: imagen)
    }
}
