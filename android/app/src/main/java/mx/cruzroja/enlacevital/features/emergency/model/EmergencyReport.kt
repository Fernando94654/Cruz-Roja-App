package mx.cruzroja.enlacevital.features.emergency.model

import mx.cruzroja.enlacevital.core.location.Coordinate

enum class ReportingFor(val label: String) {
    MYSELF("Para mí"),
    SOMEONE_ELSE("Para otra persona"),
    FAMILY_MEMBER("Para un familiar"),
}

data class EmergencyReport(
    val reportingFor: ReportingFor = ReportingFor.MYSELF,
    val patientName: String? = null,
    val reason: String = "",
    val injuredCount: Int = 1,
    val injury: String = "",
    val place: String = "",
    val reference: String = "",
    val mentalState: String = "",
    val breathing: String = "",
    val skin: String = "",
) {
    // Fixed result until on-device speech recognition and AI extraction exist
    fun withDictationSample() = copy(
        reason = "Caída en casa",
        injuredCount = 1,
        injury = "Golpe en la cabeza",
        place = "Casa habitación",
        reference = "2.º piso, puerta azul",
        mentalState = "Confundido",
        breathing = "Normal",
        skin = "Pálida",
    )

    companion object {
        val MENTAL_STATES = listOf("Alerta", "Confundido", "Inconsciente")
        val BREATHING_OPTIONS = listOf("Normal", "Con dificultad", "No respira")
        val SKIN_COLORS = listOf("Normal", "Pálida", "Azulada")
    }
}

data class EmergencyLocation(val coordinate: Coordinate, val address: String, val accuracyMeters: Int) {
    companion object {
        // Fixed until real location is wired
        val CURRENT = EmergencyLocation(
            coordinate = Coordinate.MONTERREY,
            address = "Av. Eugenio Garza Sada 2501 Sur, Monterrey, N.L.",
            accuracyMeters = 5,
        )
    }
}
