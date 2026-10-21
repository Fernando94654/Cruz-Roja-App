package mx.cruzroja.enlacevital.features.learn.model

data class Lesson(val id: String, val title: String, val duration: String, val summary: String, val steps: List<String>)

val sampleLessons = listOf(
    Lesson(
        "cpr", "RCP", "4:32",
        "Cómo dar compresiones en el pecho a un adulto que no respira mientras llega la ambulancia.",
        listOf(
            "Coloca las manos en el centro del pecho.",
            "Comprime al menos cinco centímetros, de cien a ciento veinte veces por minuto.",
            "Deja que el pecho regrese por completo entre compresiones.",
            "No te detengas hasta que llegue ayuda o la persona responda.",
        ),
    ),
    Lesson(
        "choking", "Atragantamiento", "3:10",
        "Qué hacer si alguien no puede respirar, toser ni hablar.",
        listOf(
            "Reconoce la señal: manos en el cuello y sin poder hablar.",
            "Da cinco golpes en la espalda y luego cinco compresiones abdominales.",
            "En embarazadas o personas con obesidad, comprime en el pecho.",
        ),
    ),
    Lesson(
        "bleeding", "Hemorragias", "2:45",
        "Cómo controlar un sangrado con presión directa.",
        listOf(
            "Presiona firme y directo con una tela limpia.",
            "Si se empapa, agrega más tela sin quitar la primera.",
            "El torniquete solo se usa en brazos o piernas cuando la presión no funciona.",
        ),
    ),
    Lesson(
        "burns", "Quemaduras", "3:05",
        "Primeros pasos ante quemaduras leves y graves.",
        listOf(
            "Enfría con agua corriente al menos diez minutos.",
            "No uses hielo, mantequilla ni pasta de dientes.",
            "Cubre con un apósito limpio y no revientes las ampollas.",
        ),
    ),
)
