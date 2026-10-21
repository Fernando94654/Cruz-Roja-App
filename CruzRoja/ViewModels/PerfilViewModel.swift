import Foundation
import Observation

/// Lógica de la pantalla de perfil médico: carga, guarda y valida.
/// Las vistas solo leen este estado y llaman a sus funciones.
@MainActor
@Observable
final class PerfilViewModel {
    enum Estado: Equatable {
        case cargando
        case vacio  // el usuario aún no tiene perfil
        case listo
        case error(String)
    }

    private(set) var perfil: PerfilMedico?
    private(set) var estado: Estado = .cargando
    /// `true` si no hubo conexión y se muestra la última copia guardada.
    private(set) var usandoCopiaLocal = false
    private(set) var guardando = false
    /// Mensaje para la alerta cuando falla el guardado.
    var mensajeError: String?

    private let servicio: PerfilServicio
    private let cache: PerfilCache
    private let usuarioID: Int

    init(
        servicio: PerfilServicio = PerfilServicioAPI(),
        cache: PerfilCache = PerfilCache(),
        usuarioID: Int = APIConfig.usuarioDemoID
    ) {
        self.servicio = servicio
        self.cache = cache
        self.usuarioID = usuarioID
    }

    /// Pide el perfil al API (GET). Si no hay conexión, usa la copia local.
    func cargar() async {
        if perfil == nil {
            // Muestra de inmediato la copia local mientras responde el servidor.
            perfil = cache.cargar()
            estado = perfil == nil ? .cargando : .listo
        }

        do {
            let remoto = try await servicio.obtenerPerfil(usuarioID: usuarioID)
            usandoCopiaLocal = false
            perfil = remoto
            if let remoto {
                cache.guardar(remoto)
                estado = .listo
            } else {
                cache.borrar()
                estado = .vacio
            }
        } catch {
            // Si la pantalla se cerró a media carga, no hay nada que mostrar.
            if Task.isCancelled { return }
            if perfil != nil {
                usandoCopiaLocal = true
                estado = .listo
            } else {
                estado = .error(error.localizedDescription)
            }
        }
    }

    /// Valida y guarda el perfil en el API (PUT).
    /// Regresa `true` si se guardó, para que la vista se cierre.
    @discardableResult
    func guardar(_ borrador: PerfilMedico) async -> Bool {
        let limpio = borrador.limpio()
        let errores = limpio.erroresDeValidacion
        guard errores.isEmpty else {
            mensajeError = errores.joined(separator: "\n")
            return false
        }

        guardando = true
        defer { guardando = false }

        do {
            let guardado = try await servicio.guardarPerfil(limpio, usuarioID: usuarioID)
            perfil = guardado
            cache.guardar(guardado)
            usandoCopiaLocal = false
            estado = .listo
            return true
        } catch {
            mensajeError = error.localizedDescription
            return false
        }
    }
}
