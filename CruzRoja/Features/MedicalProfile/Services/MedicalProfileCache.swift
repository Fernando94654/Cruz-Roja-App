import Foundation

/// Copia local del último perfil recibido del API.
///
/// Sirve para dos cosas:
/// 1. Mostrar el perfil y su QR aunque no haya internet (en una emergencia importa).
/// 2. Que otros módulos lean el perfil sin esperar al servidor, por ejemplo:
///        let perfil = PerfilCache().cargar()
///        reporte.perfilResumen = perfil?.resumenParaReporte
///
/// El archivo se guarda con protección de datos completa de iOS:
/// solo se puede leer con el teléfono desbloqueado.
struct PerfilCache: Sendable {
    let archivo: URL

    init(directorio: URL? = nil) {
        let carpeta = directorio
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        archivo = carpeta.appending(path: "perfil-medico.json")
    }

    func cargar() -> PerfilMedico? {
        guard let datos = try? Data(contentsOf: archivo) else { return nil }
        return try? JSONDecoder().decode(PerfilMedico.self, from: datos)
    }

    func guardar(_ perfil: PerfilMedico) {
        do {
            try FileManager.default.createDirectory(
                at: archivo.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let datos = try JSONEncoder().encode(perfil)
            try datos.write(to: archivo, options: [.atomic, .completeFileProtection])
        } catch {
            print("No se pudo guardar la copia local del perfil: \(error)")
        }
    }

    func borrar() {
        try? FileManager.default.removeItem(at: archivo)
    }
}
