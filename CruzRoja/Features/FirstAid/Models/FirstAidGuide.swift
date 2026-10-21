import Foundation

struct PasoGuia: Hashable {
    let titulo: String
    let instruccion: String
    let icono: String
    var segundos: Int? = nil
    var ritmo: Int? = nil
}

struct Emergencia: Identifiable, Hashable {
    let id: String
    let titulo: String
    let icono: String
    let palabras: [String]
    let pagina: Int
    let pasos: [PasoGuia]
}

let emergencias = [
    Emergencia(
        id: "paro", titulo: "Paro cardiaco", icono: "heart.slash.fill",
        palabras: ["no respira", "no responde", "infarto", "corazón", "corazon", "paro", "rcp", "inconsciente"],
        pagina: 34,
        pasos: [
            PasoGuia(titulo: "Revisa la escena", instruccion: "Asegúrate de que el lugar sea seguro para ti y para la persona.", icono: "eye.fill"),
            PasoGuia(titulo: "Revisa si responde", instruccion: "Toca sus hombros y pregunta en voz alta si está bien. Observa si respira durante diez segundos.", icono: "hand.tap.fill", segundos: 10),
            PasoGuia(titulo: "Coloca tus manos", instruccion: "Pon el talón de una mano en el centro del pecho y la otra encima, con los dedos entrelazados.", icono: "hands.clap.fill"),
            PasoGuia(titulo: "Compresiones", instruccion: "Presiona fuerte y rápido, unos cinco centímetros, siguiendo el ritmo. Haz treinta compresiones.", icono: "waveform.path.ecg", segundos: 18, ritmo: 110),
            PasoGuia(titulo: "No te detengas", instruccion: "Si no sabes dar respiraciones de rescate, sigue solo con compresiones hasta que llegue la ambulancia.", icono: "arrow.clockwise.heart.fill", ritmo: 110),
        ]
    ),
    Emergencia(
        id: "atragantamiento", titulo: "Atragantamiento", icono: "lungs.fill",
        palabras: ["atragant", "ahog", "no puede hablar", "trag", "comida", "garganta"],
        pagina: 41,
        pasos: [
            PasoGuia(titulo: "Pregunta", instruccion: "Pregunta si se está atragantando. Si puede toser con fuerza, anímalo a seguir tosiendo.", icono: "questionmark.bubble.fill"),
            PasoGuia(titulo: "Golpes en la espalda", instruccion: "Inclínalo hacia adelante y da cinco golpes firmes entre los omóplatos con el talón de la mano.", icono: "hand.raised.fill"),
            PasoGuia(titulo: "Compresiones abdominales", instruccion: "Colócate detrás, pon tu puño sobre el ombligo y empuja hacia adentro y hacia arriba cinco veces.", icono: "figure.stand"),
            PasoGuia(titulo: "Repite", instruccion: "Alterna cinco golpes y cinco compresiones hasta que el objeto salga o la persona pierda el conocimiento.", icono: "repeat"),
        ]
    ),
    Emergencia(
        id: "hemorragia", titulo: "Hemorragia", icono: "drop.fill",
        palabras: ["sangr", "herida", "cortad", "corté", "corte", "hemorragia"],
        pagina: 52,
        pasos: [
            PasoGuia(titulo: "Protégete", instruccion: "Protege tus manos con guantes o una bolsa de plástico.", icono: "hand.raised.square.fill"),
            PasoGuia(titulo: "Presión directa", instruccion: "Presiona con firmeza sobre la herida con una tela limpia. No la retires.", icono: "hand.point.down.fill", segundos: 60),
            PasoGuia(titulo: "Agrega más tela", instruccion: "Si la tela se empapa, pon otra encima y sigue presionando.", icono: "square.stack.fill"),
            PasoGuia(titulo: "Mantén el calor", instruccion: "Mantén a la persona acostada y abrigada hasta que llegue la ambulancia.", icono: "thermometer.medium"),
        ]
    ),
    Emergencia(
        id: "quemadura", titulo: "Quemadura", icono: "flame.fill",
        palabras: ["quem", "fuego", "aceite", "agua caliente", "ampolla"],
        pagina: 60,
        pasos: [
            PasoGuia(titulo: "Aleja la fuente", instruccion: "Detén la quemadura alejando a la persona de la fuente de calor.", icono: "xmark.octagon.fill"),
            PasoGuia(titulo: "Enfría con agua", instruccion: "Enfría la zona con agua corriente fría, no helada, durante al menos diez minutos.", icono: "drop.triangle.fill", segundos: 600),
            PasoGuia(titulo: "Retira objetos", instruccion: "Quita anillos o ropa cerca de la quemadura, solo si no está pegada a la piel.", icono: "circle.dashed"),
            PasoGuia(titulo: "Cubre", instruccion: "Cubre con plástico limpio o un apósito que no se pegue. No pongas cremas ni hielo.", icono: "bandage.fill"),
        ]
    ),
    Emergencia(
        id: "convulsion", titulo: "Convulsión", icono: "bolt.heart.fill",
        palabras: ["convuls", "ataque", "epilep", "temblor", "sacud"],
        pagina: 73,
        pasos: [
            PasoGuia(titulo: "Despeja el área", instruccion: "Retira objetos cercanos con los que pueda golpearse.", icono: "square.dashed"),
            PasoGuia(titulo: "Protege la cabeza", instruccion: "Pon algo suave bajo su cabeza. No lo sujetes ni pongas nada en su boca.", icono: "person.crop.circle.badge.exclamationmark"),
            PasoGuia(titulo: "Mide el tiempo", instruccion: "Toma el tiempo de la convulsión. Si dura más de cinco minutos, avisa a la ambulancia.", icono: "stopwatch.fill", segundos: 300),
            PasoGuia(titulo: "Ponlo de lado", instruccion: "Cuando termine, colócalo de lado y quédate con él hasta que despierte por completo.", icono: "bed.double.fill"),
        ]
    ),
    Emergencia(
        id: "desmayo", titulo: "Desmayo", icono: "figure.fall",
        palabras: ["desmay", "mare", "se cayó", "perdió el conocimiento"],
        pagina: 78,
        pasos: [
            PasoGuia(titulo: "Acuéstalo", instruccion: "Recuesta a la persona boca arriba en un lugar seguro.", icono: "bed.double.fill"),
            PasoGuia(titulo: "Eleva las piernas", instruccion: "Levanta sus piernas unos treinta centímetros para ayudar a la circulación.", icono: "arrow.up.circle.fill"),
            PasoGuia(titulo: "Afloja la ropa", instruccion: "Afloja cinturones, corbatas o ropa ajustada.", icono: "tshirt.fill"),
            PasoGuia(titulo: "Vigila la respiración", instruccion: "Si no despierta en un minuto o deja de respirar, prepárate para dar RCP.", icono: "lungs.fill", segundos: 60),
        ]
    ),
]
