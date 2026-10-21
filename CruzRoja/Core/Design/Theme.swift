import SwiftUI
import MapKit

extension Color {
    // manual de identidad: PMS 485 y negro
    static let rojo = Color(red: 238/255, green: 20/255, blue: 10/255) // #EE140A
}

extension Font {
    // Helvetica bold, la tipografía institucional
    static func marca(_ tamano: CGFloat) -> Font {
        .custom("HelveticaNeue-Bold", size: tamano)
    }
}

// para las capturas: -demo reporte, -demo familia, etc.
let demo = UserDefaults.standard.string(forKey: "demo") ?? ""

let monterrey = CLLocationCoordinate2D(latitude: 25.6516, longitude: -100.2895)

enum Pantalla: Hashable {
    case reporte, resumen, auxilios
    case guia(Emergencia)
}

@Observable
class Reporte {
    var paraQuien = "Para mí"
    var nombre: String? = nil
    var motivo = ""
    var lesionados = 1
    var lesion = ""
    var lugar = ""
    var referencia = ""
    var estadoMental = ""
    var respiracion = ""
    var piel = ""
    var enviado = false

    // texto fijo, no hay reconocimiento de voz real
    func dictar() {
        motivo = "Caída en casa"
        lesionados = 1
        lesion = "Golpe en la cabeza"
        lugar = "Casa habitación"
        referencia = "2.º piso, puerta azul"
        estadoMental = "Confundido"
        respiracion = "Normal"
        piel = "Pálida"
    }
}

let direccion = "Av. Eugenio Garza Sada 2501 Sur, Monterrey, N.L."

struct Familiar: Identifiable {
    let id = UUID()
    let nombre: String
    let estado: String
    let alerta: Bool
    let coordenada: CLLocationCoordinate2D
}

let familia = [
    Familiar(nombre: "Mamá", estado: "Alerta activa", alerta: true,
             coordenada: .init(latitude: 25.6600, longitude: -100.3000)),
    Familiar(nombre: "Papá", estado: "Bien · hace 1 h", alerta: false,
             coordenada: .init(latitude: 25.6450, longitude: -100.2800)),
    Familiar(nombre: "Hermana", estado: "Bien · hace 3 h", alerta: false,
             coordenada: .init(latitude: 25.6700, longitude: -100.3100)),
]

struct Leccion: Identifiable, Hashable {
    let id = UUID()
    let titulo: String
    let duracion: String
    let descripcion: String
    let pasos: [String]
}

let lecciones = [
    Leccion(titulo: "RCP", duracion: "4:32",
            descripcion: "Cómo dar compresiones en el pecho a un adulto que no respira mientras llega la ambulancia.",
            pasos: ["Coloca las manos en el centro del pecho.",
                    "Comprime al menos cinco centímetros, de cien a ciento veinte veces por minuto.",
                    "Deja que el pecho regrese por completo entre compresiones.",
                    "No te detengas hasta que llegue ayuda o la persona responda."]),
    Leccion(titulo: "Atragantamiento", duracion: "3:10",
            descripcion: "Qué hacer si alguien no puede respirar, toser ni hablar.",
            pasos: ["Reconoce la señal: manos en el cuello y sin poder hablar.",
                    "Da cinco golpes en la espalda y luego cinco compresiones abdominales.",
                    "En embarazadas o personas con obesidad, comprime en el pecho."]),
    Leccion(titulo: "Hemorragias", duracion: "2:45",
            descripcion: "Cómo controlar un sangrado con presión directa.",
            pasos: ["Presiona firme y directo con una tela limpia.",
                    "Si se empapa, agrega más tela sin quitar la primera.",
                    "El torniquete solo se usa en brazos o piernas cuando la presión no funciona."]),
    Leccion(titulo: "Quemaduras", duracion: "3:05",
            descripcion: "Primeros pasos ante quemaduras leves y graves.",
            pasos: ["Enfría con agua corriente al menos diez minutos.",
                    "No uses hielo, mantequilla ni pasta de dientes.",
                    "Cubre con un apósito limpio y no revientes las ampollas."]),
]
