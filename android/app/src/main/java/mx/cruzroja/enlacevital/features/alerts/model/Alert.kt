package mx.cruzroja.enlacevital.features.alerts.model

import java.time.Duration
import java.time.Instant
import java.util.UUID

data class OfficialAlert(
    val source: String,
    val title: String,
    val message: String? = null,
    val areaName: String,
    val issuedAt: Instant,
    val isWeather: Boolean = false,
    val id: String = UUID.randomUUID().toString(),
)

// Wire values match the backend's community_report_type enum
enum class CommunityReportCategory(val wireValue: String, val label: String) {
    FLOOD("flood", "Inundación"),
    BLOCKED_STREET("blocked_street", "Calle bloqueada"),
    FALLEN_TREE("fallen_tree", "Árbol caído"),
    POWER_OUTAGE("power_outage", "Apagón"),
    FIRE("fire", "Incendio"),
    TRAFFIC_LIGHT("traffic_light", "Semáforo"),
    ACCIDENT("accident", "Accidente"),
    OTHER("other", "Otro"),
}

data class CommunityReport(
    val category: CommunityReportCategory,
    val title: String,
    val confirmations: Int,
    val expiresAt: Instant,
    val confirmedByMe: Boolean = false,
    val id: String = UUID.randomUUID().toString(),
)

fun sampleOfficialAlerts(now: Instant = Instant.now()) = listOf(
    OfficialAlert(
        source = "Protección Civil NL",
        title = "Lluvia intensa en tu zona",
        message = "Evita cruzar calles inundadas y mantente en un lugar seguro.",
        areaName = "Monterrey",
        issuedAt = now.minus(Duration.ofMinutes(20)),
        isWeather = true,
    ),
    OfficialAlert(
        source = "SMN",
        title = "Lluvias intensas en el área metropolitana",
        areaName = "San Nicolás",
        issuedAt = now.minus(Duration.ofHours(2)),
        isWeather = true,
    ),
)

fun sampleCommunityReports(now: Instant = Instant.now()) = listOf(
    CommunityReport(CommunityReportCategory.FLOOD, "Calle inundada a 400 m", 6, now.plus(Duration.ofHours(3))),
    CommunityReport(CommunityReportCategory.TRAFFIC_LIGHT, "Semáforo apagado en el cruce", 2, now.plus(Duration.ofHours(2))),
    CommunityReport(CommunityReportCategory.FALLEN_TREE, "Árbol bloqueando un carril", 1, now.plus(Duration.ofHours(2))),
)
