import Foundation

/// Configuración compartida para conectarse al API del equipo.
enum APIConfig {
    /// Dirección del API.
    /// - Simulador: 127.0.0.1 funciona porque comparte red con la Mac.
    /// - iPhone físico: usa la IP de la Mac, por ejemplo "http://192.168.1.50:8000",
    ///   e inicia el API con: uvicorn app.main:app --host 0.0.0.0
    static let baseURL = URL(string: "http://127.0.0.1:8000")!

    /// Usuario de demostración mientras no exista el inicio de sesión real.
    /// Se crea en el API con: python -m app.seed
    static let usuarioDemoID = 1

    /// Segundos que se espera una respuesta antes de marcar error de conexión.
    static let tiempoDeEspera: TimeInterval = 10
}
