package mx.cruzroja.enlacevital.features.firstaid.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import mx.cruzroja.enlacevital.core.speech.SpeechSynthesizing
import mx.cruzroja.enlacevital.features.emergency.data.AmbulanceTracker
import mx.cruzroja.enlacevital.features.firstaid.model.FirstAidGuide
import mx.cruzroja.enlacevital.features.firstaid.model.GuideStep

data class GuideUiState(
    val guide: FirstAidGuide,
    val stepIndex: Int = 0,
    val secondsLeft: Int? = null,
    // Toggles on every compression beat so the view can pulse and vibrate
    val beat: Boolean = false,
) {
    val step: GuideStep get() = guide.steps[stepIndex]
    val isFirstStep: Boolean get() = stepIndex == 0
    val isLastStep: Boolean get() = stepIndex == guide.steps.lastIndex
}

class GuideViewModel(
    guide: FirstAidGuide,
    val speech: SpeechSynthesizing,
    val ambulance: AmbulanceTracker,
) : ViewModel() {
    private val _state = MutableStateFlow(GuideUiState(guide))
    val state: StateFlow<GuideUiState> = _state.asStateFlow()
    private var stepJobs: List<Job> = emptyList()

    init {
        ambulance.request()
        startStep()
        viewModelScope.launch {
            ambulance.state.distinctUntilChangedBy { it.hasArrived }.collect {
                if (it.hasArrived) speech.speak("La ambulancia llegó. Cuéntale a los paramédicos qué pasó y qué hiciste.")
            }
        }
    }

    fun next() {
        if (_state.value.isLastStep) return
        _state.update { it.copy(stepIndex = it.stepIndex + 1) }
        startStep()
    }

    fun previous() {
        if (_state.value.isFirstStep) return
        _state.update { it.copy(stepIndex = it.stepIndex - 1) }
        startStep()
    }

    fun repeatInstruction() = speech.speak(_state.value.step.instruction)

    fun toggleMute() = speech.setMuted(!speech.isMuted.value)

    fun stop() = speech.stop()

    // Speaks the step, runs its timer and its compression rhythm
    private fun startStep() {
        stepJobs.forEach { it.cancel() }
        val step = _state.value.step
        _state.update { it.copy(secondsLeft = step.seconds) }
        speech.speak("${step.title}. ${step.instruction}")
        val timer = viewModelScope.launch {
            while ((_state.value.secondsLeft ?: 0) > 0) {
                delay(1000)
                _state.update { it.copy(secondsLeft = it.secondsLeft?.minus(1)) }
            }
            if (_state.value.secondsLeft == 0) speech.speak("Tiempo cumplido.")
        }
        val beat = viewModelScope.launch {
            val rate = step.rate ?: return@launch
            while (isActive) {
                delay(60_000L / rate)
                _state.update { it.copy(beat = !it.beat) }
            }
        }
        stepJobs = listOf(timer, beat)
    }

    override fun onCleared() {
        speech.stop()
    }
}
