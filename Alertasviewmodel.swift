import Foundation
import Observation

@MainActor
@Observable
class AlertasViewModel {

    var alertasOficiales = [
        AlertaOficial(fuente: "SMN",
                      titulo: "Lluvias intensas en el área metropolitana",
                      zona: "Monterrey",
                      fecha: Date().addingTimeInterval(-3600)),
        AlertaOficial(fuente: "Protección Civil NL",
                      titulo: "Evitar cruces inundables",
                      zona: "San Nicolás",
                      fecha: Date().addingTimeInterval(-7200))
    ]

    var reportes = [
        ReporteVecinal(categoria: "Inundación",
                       titulo: "Calle inundada",
                       confirmaciones: 3,
                       expira: Date().addingTimeInterval(3 * 3600)),
        ReporteVecinal(categoria: "Árbol caído",
                       titulo: "Árbol bloqueando un carril",
                       confirmaciones: 1,
                       expira: Date().addingTimeInterval(2 * 3600))
    ]

    var reportesVigentes: [ReporteVecinal] {
        reportes.filter { $0.expira > Date() }
    }

    func confirmar(_ reporte: ReporteVecinal) {
        guard let i = reportes.firstIndex(where: { $0.id == reporte.id }) else { return }
        if reportes[i].yaConfirme { return }
        reportes[i].confirmaciones += 1
        reportes[i].yaConfirme = true
    }

    func agregarReporte(categoria: String, titulo: String) {
        let nuevo = ReporteVecinal(categoria: categoria,
                                   titulo: titulo,
                                   confirmaciones: 0,
                                   expira: Date().addingTimeInterval(4 * 3600))
        reportes.insert(nuevo, at: 0)
    }
}
