import Foundation

struct AlertaOficial: Identifiable {
    var id = UUID()
    var fuente: String
    var titulo: String
    var zona: String
    var fecha: Date
}

struct ReporteVecinal: Identifiable {
    var id = UUID()
    var categoria: String
    var titulo: String
    var confirmaciones: Int
    var yaConfirme: Bool = false
    var expira: Date
}
