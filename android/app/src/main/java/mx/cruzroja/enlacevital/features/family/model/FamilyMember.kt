package mx.cruzroja.enlacevital.features.family.model

import mx.cruzroja.enlacevital.core.location.Coordinate
import java.util.UUID

data class FamilyMember(
    val name: String,
    val status: String,
    val hasAlert: Boolean,
    val coordinate: Coordinate,
    val id: String = UUID.randomUUID().toString(),
)

// Heart-rate alert raised by a member's watch
data class FamilyAlert(val memberName: String, val title: String, val detail: String, val reason: String) {
    companion object {
        val SAMPLE = FamilyAlert(
            memberName = "Mamá",
            title = "Mamá registró un ritmo cardiaco anormal",
            detail = "Hace 2 min · Apple Watch",
            reason = "Ritmo cardiaco anormal",
        )
    }
}

val sampleFamilyMembers = listOf(
    FamilyMember("Mamá", "Alerta activa", true, Coordinate(25.6600, -100.3000)),
    FamilyMember("Papá", "Bien · hace 1 h", false, Coordinate(25.6450, -100.2800)),
    FamilyMember("Hermana", "Bien · hace 3 h", false, Coordinate(25.6700, -100.3100)),
)
