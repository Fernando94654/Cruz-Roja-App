import Foundation

/// Lo que necesita el ViewModel para leer y guardar el perfil.
/// Es un protocolo para poder usar un servicio falso en las pruebas.
protocol PerfilServicio: Sendable {
    /// Regresa el perfil, o `nil` si el usuario aún no tiene uno (404).
    func obtenerPerfil(usuarioID: Int) async throws -> PerfilMedico?
    /// Crea o reemplaza el perfil y regresa cómo quedó guardado.
    func guardarPerfil(_ perfil: PerfilMedico, usuarioID: Int) async throws -> PerfilMedico
}

enum ErrorAPI: LocalizedError, Equatable {
    case sinConexion
    case respuestaInvalida
    case datosInvalidos(String)
    case servidor(codigo: Int, mensaje: String?)

    var errorDescription: String? {
        switch self {
        case .sinConexion:
            return "No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo."
        case .respuestaInvalida:
            return "El servidor respondió algo inesperado."
        case .datosInvalidos(let mensaje):
            return "Revisa los datos: \(mensaje)"
        case .servidor(let codigo, let mensaje):
            return mensaje ?? "Error del servidor (\(codigo))."
        }
    }
}

/// Conexión real con el API:
/// GET /usuarios/{id}/perfil y PUT /usuarios/{id}/perfil
struct PerfilServicioAPI: PerfilServicio {
    var baseURL: URL = APIConfig.baseURL
    var session: URLSession = .shared

    func obtenerPerfil(usuarioID: Int) async throws -> PerfilMedico? {
        let peticion = URLRequest(url: url(usuarioID), timeoutInterval: APIConfig.tiempoDeEspera)
        let (datos, respuesta) = try await enviar(peticion)
        if respuesta.statusCode == 404 { return nil }
        try verificar(respuesta, datos)
        return try decodificar(datos)
    }

    func guardarPerfil(_ perfil: PerfilMedico, usuarioID: Int) async throws -> PerfilMedico {
        var peticion = URLRequest(url: url(usuarioID), timeoutInterval: APIConfig.tiempoDeEspera)
        peticion.httpMethod = "PUT"
        peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
        peticion.httpBody = try JSONEncoder().encode(perfil)
        let (datos, respuesta) = try await enviar(peticion)
        try verificar(respuesta, datos)
        return try decodificar(datos)
    }

    // MARK: - Auxiliares

    private func url(_ usuarioID: Int) -> URL {
        baseURL.appending(path: "usuarios/\(usuarioID)/perfil")
    }

    private func enviar(_ peticion: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (datos, respuesta) = try await session.data(for: peticion)
            guard let http = respuesta as? HTTPURLResponse else { throw ErrorAPI.respuestaInvalida }
            return (datos, http)
        } catch is URLError {
            throw ErrorAPI.sinConexion
        }
    }

    private func verificar(_ respuesta: HTTPURLResponse, _ datos: Data) throws {
        switch respuesta.statusCode {
        case 200..<300:
            return
        case 422:
            throw ErrorAPI.datosInvalidos(Self.mensaje(de: datos) ?? "algún campo no es válido.")
        default:
            throw ErrorAPI.servidor(codigo: respuesta.statusCode, mensaje: Self.mensaje(de: datos))
        }
    }

    private func decodificar(_ datos: Data) throws -> PerfilMedico {
        do {
            return try JSONDecoder().decode(PerfilMedico.self, from: datos)
        } catch {
            throw ErrorAPI.respuestaInvalida
        }
    }

    /// FastAPI manda los errores en "detail": a veces es texto y a veces una lista.
    static func mensaje(de datos: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else {
            return nil
        }
        if let texto = json["detail"] as? String {
            return texto
        }
        if let lista = json["detail"] as? [[String: Any]], let msg = lista.first?["msg"] as? String {
            return msg.replacingOccurrences(of: "Value error, ", with: "")
        }
        return nil
    }
}
