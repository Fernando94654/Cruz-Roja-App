package mx.cruzroja.enlacevital.core.design

import java.time.Duration
import java.time.Instant

// Spanish relative time: "hace 20 min", "en 3 h 5 min"
fun relativeTime(instant: Instant, now: Instant = Instant.now()): String {
    val minutes = Duration.between(now, instant).toMinutes()
    val absolute = kotlin.math.abs(minutes)
    val text = when {
        absolute < 1 -> return "ahora"
        absolute < 60 -> "$absolute min"
        absolute % 60 == 0L -> "${absolute / 60} h"
        else -> "${absolute / 60} h ${absolute % 60} min"
    }
    return if (minutes < 0) "hace $text" else "en $text"
}
