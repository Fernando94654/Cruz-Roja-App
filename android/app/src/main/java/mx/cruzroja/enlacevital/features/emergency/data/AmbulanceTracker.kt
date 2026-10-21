package mx.cruzroja.enlacevital.features.emergency.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AmbulanceState(val isOnTheWay: Boolean = false, val secondsLeft: Int = 0, val totalSeconds: Int = 0) {
    val hasArrived: Boolean get() = isOnTheWay && secondsLeft == 0
    val progress: Float get() = if (totalSeconds > 0) 1f - secondsLeft.toFloat() / totalSeconds else 0f
    val timeLeft: String get() = "%d:%02d".format(secondsLeft / 60, secondsLeft % 60)
    val status: String
        get() = when {
            hasArrived -> "La ambulancia llegó"
            secondsLeft in 1..59 -> "Llegando"
            else -> "En camino"
        }
}

// Simulated ambulance: the countdown runs 4x faster for demos
class AmbulanceTracker(private val scope: CoroutineScope) {
    val unit = "Ambulancia 214"
    private val _state = MutableStateFlow(AmbulanceState())
    val state: StateFlow<AmbulanceState> = _state.asStateFlow()
    private var job: Job? = null

    fun request(seconds: Int = 480) {
        if (job != null) return
        _state.value = AmbulanceState(isOnTheWay = true, secondsLeft = seconds, totalSeconds = seconds)
        job = scope.launch {
            while (_state.value.secondsLeft > 0) {
                delay(250)
                _state.value = _state.value.copy(secondsLeft = _state.value.secondsLeft - 1)
            }
        }
    }
}
