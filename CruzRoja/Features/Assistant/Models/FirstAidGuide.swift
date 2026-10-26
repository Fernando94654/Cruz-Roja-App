import Foundation

struct GuideStep: Hashable, Sendable, Codable {
    let title: String
    let instruction: String
    let icon: String
    var seconds: Int? = nil
    // Compressions per minute, when the step has a rhythm
    var rate: Int? = nil
}

struct FirstAidGuide: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let title: String
    let icon: String
    let keywords: [String]
    let steps: [GuideStep]
}

// Content based on Cruz Roja protocols. GET /guides serves the same guides; this copy ships
// with the app so the guidance still works offline, the moment the network matters most
extension FirstAidGuide {
    static let bundled = [
        FirstAidGuide(
            id: "cardiac_arrest", title: "Paro cardiaco", icon: "heart.slash.fill",
            keywords: ["no respira", "no responde", "infarto", "corazón", "corazon", "paro", "rcp", "inconsciente"],
            steps: [
                GuideStep(title: "Revisa la escena", instruction: "Asegúrate de que el lugar sea seguro para ti y para la persona.", icon: "eye.fill"),
                GuideStep(title: "Revisa si responde", instruction: "Toca sus hombros y pregunta en voz alta si está bien. Observa si respira durante diez segundos.", icon: "hand.tap.fill", seconds: 10),
                GuideStep(title: "Coloca tus manos", instruction: "Pon el talón de una mano en el centro del pecho y la otra encima, con los dedos entrelazados.", icon: "hands.clap.fill"),
                GuideStep(title: "Compresiones", instruction: "Presiona fuerte y rápido, unos cinco centímetros, siguiendo el ritmo. Haz treinta compresiones.", icon: "waveform.path.ecg", seconds: 18, rate: 110),
                GuideStep(title: "No te detengas", instruction: "Si no sabes dar respiraciones de rescate, sigue solo con compresiones hasta que llegue la ambulancia.", icon: "arrow.clockwise.heart.fill", rate: 110),
            ]
        ),
        FirstAidGuide(
            id: "choking", title: "Atragantamiento", icon: "lungs.fill",
            keywords: ["atragant", "ahog", "no puede hablar", "trag", "comida", "garganta"],
            steps: [
                GuideStep(title: "Pregunta", instruction: "Pregunta si se está atragantando. Si puede toser con fuerza, anímalo a seguir tosiendo.", icon: "questionmark.bubble.fill"),
                GuideStep(title: "Golpes en la espalda", instruction: "Inclínalo hacia adelante y da cinco golpes firmes entre los omóplatos con el talón de la mano.", icon: "hand.raised.fill"),
                GuideStep(title: "Compresiones abdominales", instruction: "Colócate detrás, pon tu puño sobre el ombligo y empuja hacia adentro y hacia arriba cinco veces.", icon: "figure.stand"),
                GuideStep(title: "Repite", instruction: "Alterna cinco golpes y cinco compresiones hasta que el objeto salga o la persona pierda el conocimiento.", icon: "repeat"),
            ]
        ),
        FirstAidGuide(
            id: "bleeding", title: "Hemorragia", icon: "drop.fill",
            keywords: ["sangr", "herida", "cortad", "corté", "corte", "hemorragia"],
            steps: [
                GuideStep(title: "Protégete", instruction: "Protege tus manos con guantes o una bolsa de plástico.", icon: "hand.raised.square.fill"),
                GuideStep(title: "Presión directa", instruction: "Presiona con firmeza sobre la herida con una tela limpia. No la retires.", icon: "hand.point.down.fill", seconds: 60),
                GuideStep(title: "Agrega más tela", instruction: "Si la tela se empapa, pon otra encima y sigue presionando.", icon: "square.stack.fill"),
                GuideStep(title: "Mantén el calor", instruction: "Mantén a la persona acostada y abrigada hasta que llegue la ambulancia.", icon: "thermometer.medium"),
            ]
        ),
        FirstAidGuide(
            id: "burn", title: "Quemadura", icon: "flame.fill",
            keywords: ["quem", "fuego", "aceite", "agua caliente", "ampolla"],
            steps: [
                GuideStep(title: "Aleja la fuente", instruction: "Detén la quemadura alejando a la persona de la fuente de calor.", icon: "xmark.octagon.fill"),
                GuideStep(title: "Enfría con agua", instruction: "Enfría la zona con agua corriente fría, no helada, durante al menos diez minutos.", icon: "drop.triangle.fill", seconds: 600),
                GuideStep(title: "Retira objetos", instruction: "Quita anillos o ropa cerca de la quemadura, solo si no está pegada a la piel.", icon: "circle.dashed"),
                GuideStep(title: "Cubre", instruction: "Cubre con plástico limpio o un apósito que no se pegue. No pongas cremas ni hielo.", icon: "bandage.fill"),
            ]
        ),
        FirstAidGuide(
            id: "seizure", title: "Convulsión", icon: "bolt.heart.fill",
            keywords: ["convuls", "ataque", "epilep", "temblor", "sacud"],
            steps: [
                GuideStep(title: "Despeja el área", instruction: "Retira objetos cercanos con los que pueda golpearse.", icon: "square.dashed"),
                GuideStep(title: "Protege la cabeza", instruction: "Pon algo suave bajo su cabeza. No lo sujetes ni pongas nada en su boca.", icon: "person.crop.circle.badge.exclamationmark"),
                GuideStep(title: "Mide el tiempo", instruction: "Toma el tiempo de la convulsión. Si dura más de cinco minutos, avisa a la ambulancia.", icon: "stopwatch.fill", seconds: 300),
                GuideStep(title: "Ponlo de lado", instruction: "Cuando termine, colócalo de lado y quédate con él hasta que despierte por completo.", icon: "bed.double.fill"),
            ]
        ),
        FirstAidGuide(
            id: "fainting", title: "Desmayo", icon: "figure.fall",
            keywords: ["desmay", "mare", "se cayó", "perdió el conocimiento"],
            steps: [
                GuideStep(title: "Acuéstalo", instruction: "Recuesta a la persona boca arriba en un lugar seguro.", icon: "bed.double.fill"),
                GuideStep(title: "Eleva las piernas", instruction: "Levanta sus piernas unos treinta centímetros para ayudar a la circulación.", icon: "arrow.up.circle.fill"),
                GuideStep(title: "Afloja la ropa", instruction: "Afloja cinturones, corbatas o ropa ajustada.", icon: "tshirt.fill"),
                GuideStep(title: "Vigila la respiración", instruction: "Si no despierta en un minuto o deja de respirar, prepárate para dar RCP.", icon: "lungs.fill", seconds: 60),
            ]
        ),
    ]
}
