package mx.cruzroja.enlacevital.features.firstaid.model

data class GuideStep(
    val title: String,
    val instruction: String,
    // SF Symbol name, mapped to a Material icon in the UI
    val icon: String,
    val seconds: Int? = null,
    // Compressions per minute, when the step has a rhythm
    val rate: Int? = null,
)

data class FirstAidGuide(
    val id: String,
    val title: String,
    val icon: String,
    val keywords: List<String>,
    val manualPage: Int,
    val steps: List<GuideStep>,
) {
    // Content based on Cruz Roja protocols; will come from the backend once the RAG exists
    companion object {
        val CATALOG = listOf(
            FirstAidGuide(
                id = "cardiac_arrest", title = "Paro cardiaco", icon = "heart.slash.fill",
                keywords = listOf("no respira", "no responde", "infarto", "corazón", "corazon", "paro", "rcp", "inconsciente"),
                manualPage = 34,
                steps = listOf(
                    GuideStep(title = "Revisa la escena", instruction = "Asegúrate de que el lugar sea seguro para ti y para la persona.", icon = "eye.fill"),
                    GuideStep(title = "Revisa si responde", instruction = "Toca sus hombros y pregunta en voz alta si está bien. Observa si respira durante diez segundos.", icon = "hand.tap.fill", seconds = 10),
                    GuideStep(title = "Coloca tus manos", instruction = "Pon el talón de una mano en el centro del pecho y la otra encima, con los dedos entrelazados.", icon = "hands.clap.fill"),
                    GuideStep(title = "Compresiones", instruction = "Presiona fuerte y rápido, unos cinco centímetros, siguiendo el ritmo. Haz treinta compresiones.", icon = "waveform.path.ecg", seconds = 18, rate = 110),
                    GuideStep(title = "No te detengas", instruction = "Si no sabes dar respiraciones de rescate, sigue solo con compresiones hasta que llegue la ambulancia.", icon = "arrow.clockwise.heart.fill", rate = 110),
                )
            ),
            FirstAidGuide(
                id = "choking", title = "Atragantamiento", icon = "lungs.fill",
                keywords = listOf("atragant", "ahog", "no puede hablar", "trag", "comida", "garganta"),
                manualPage = 41,
                steps = listOf(
                    GuideStep(title = "Pregunta", instruction = "Pregunta si se está atragantando. Si puede toser con fuerza, anímalo a seguir tosiendo.", icon = "questionmark.bubble.fill"),
                    GuideStep(title = "Golpes en la espalda", instruction = "Inclínalo hacia adelante y da cinco golpes firmes entre los omóplatos con el talón de la mano.", icon = "hand.raised.fill"),
                    GuideStep(title = "Compresiones abdominales", instruction = "Colócate detrás, pon tu puño sobre el ombligo y empuja hacia adentro y hacia arriba cinco veces.", icon = "figure.stand"),
                    GuideStep(title = "Repite", instruction = "Alterna cinco golpes y cinco compresiones hasta que el objeto salga o la persona pierda el conocimiento.", icon = "repeat"),
                )
            ),
            FirstAidGuide(
                id = "bleeding", title = "Hemorragia", icon = "drop.fill",
                keywords = listOf("sangr", "herida", "cortad", "corté", "corte", "hemorragia"),
                manualPage = 52,
                steps = listOf(
                    GuideStep(title = "Protégete", instruction = "Protege tus manos con guantes o una bolsa de plástico.", icon = "hand.raised.square.fill"),
                    GuideStep(title = "Presión directa", instruction = "Presiona con firmeza sobre la herida con una tela limpia. No la retires.", icon = "hand.point.down.fill", seconds = 60),
                    GuideStep(title = "Agrega más tela", instruction = "Si la tela se empapa, pon otra encima y sigue presionando.", icon = "square.stack.fill"),
                    GuideStep(title = "Mantén el calor", instruction = "Mantén a la persona acostada y abrigada hasta que llegue la ambulancia.", icon = "thermometer.medium"),
                )
            ),
            FirstAidGuide(
                id = "burn", title = "Quemadura", icon = "flame.fill",
                keywords = listOf("quem", "fuego", "aceite", "agua caliente", "ampolla"),
                manualPage = 60,
                steps = listOf(
                    GuideStep(title = "Aleja la fuente", instruction = "Detén la quemadura alejando a la persona de la fuente de calor.", icon = "xmark.octagon.fill"),
                    GuideStep(title = "Enfría con agua", instruction = "Enfría la zona con agua corriente fría, no helada, durante al menos diez minutos.", icon = "drop.triangle.fill", seconds = 600),
                    GuideStep(title = "Retira objetos", instruction = "Quita anillos o ropa cerca de la quemadura, solo si no está pegada a la piel.", icon = "circle.dashed"),
                    GuideStep(title = "Cubre", instruction = "Cubre con plástico limpio o un apósito que no se pegue. No pongas cremas ni hielo.", icon = "bandage.fill"),
                )
            ),
            FirstAidGuide(
                id = "seizure", title = "Convulsión", icon = "bolt.heart.fill",
                keywords = listOf("convuls", "ataque", "epilep", "temblor", "sacud"),
                manualPage = 73,
                steps = listOf(
                    GuideStep(title = "Despeja el área", instruction = "Retira objetos cercanos con los que pueda golpearse.", icon = "square.dashed"),
                    GuideStep(title = "Protege la cabeza", instruction = "Pon algo suave bajo su cabeza. No lo sujetes ni pongas nada en su boca.", icon = "person.crop.circle.badge.exclamationmark"),
                    GuideStep(title = "Mide el tiempo", instruction = "Toma el tiempo de la convulsión. Si dura más de cinco minutos, avisa a la ambulancia.", icon = "stopwatch.fill", seconds = 300),
                    GuideStep(title = "Ponlo de lado", instruction = "Cuando termine, colócalo de lado y quédate con él hasta que despierte por completo.", icon = "bed.double.fill"),
                )
            ),
            FirstAidGuide(
                id = "fainting", title = "Desmayo", icon = "figure.fall",
                keywords = listOf("desmay", "mare", "se cayó", "perdió el conocimiento"),
                manualPage = 78,
                steps = listOf(
                    GuideStep(title = "Acuéstalo", instruction = "Recuesta a la persona boca arriba en un lugar seguro.", icon = "bed.double.fill"),
                    GuideStep(title = "Eleva las piernas", instruction = "Levanta sus piernas unos treinta centímetros para ayudar a la circulación.", icon = "arrow.up.circle.fill"),
                    GuideStep(title = "Afloja la ropa", instruction = "Afloja cinturones, corbatas o ropa ajustada.", icon = "tshirt.fill"),
                    GuideStep(title = "Vigila la respiración", instruction = "Si no despierta en un minuto o deja de respirar, prepárate para dar RCP.", icon = "lungs.fill", seconds = 60),
                )
            ),
        )

        fun byId(id: String) = CATALOG.first { it.id == id }
    }
}
