import Foundation

struct Lesson: Identifiable, Hashable, Sendable {
    var id = UUID()
    let title: String
    let duration: String
    let summary: String
    let steps: [String]
}

extension Lesson {
    static let samples = [
        Lesson(title: "RCP", duration: "4:32",
               summary: "Cómo dar compresiones en el pecho a un adulto que no respira mientras llega la ambulancia.",
               steps: ["Coloca las manos en el centro del pecho.",
                       "Comprime al menos cinco centímetros, de cien a ciento veinte veces por minuto.",
                       "Deja que el pecho regrese por completo entre compresiones.",
                       "No te detengas hasta que llegue ayuda o la persona responda."]),
        Lesson(title: "Atragantamiento", duration: "3:10",
               summary: "Qué hacer si alguien no puede respirar, toser ni hablar.",
               steps: ["Reconoce la señal: manos en el cuello y sin poder hablar.",
                       "Da cinco golpes en la espalda y luego cinco compresiones abdominales.",
                       "En embarazadas o personas con obesidad, comprime en el pecho."]),
        Lesson(title: "Hemorragias", duration: "2:45",
               summary: "Cómo controlar un sangrado con presión directa.",
               steps: ["Presiona firme y directo con una tela limpia.",
                       "Si se empapa, agrega más tela sin quitar la primera.",
                       "El torniquete solo se usa en brazos o piernas cuando la presión no funciona."]),
        Lesson(title: "Quemaduras", duration: "3:05",
               summary: "Primeros pasos ante quemaduras leves y graves.",
               steps: ["Enfría con agua corriente al menos diez minutos.",
                       "No uses hielo, mantequilla ni pasta de dientes.",
                       "Cubre con un apósito limpio y no revientes las ampollas."]),
    ]
}
