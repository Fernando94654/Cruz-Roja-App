package mx.cruzroja.enlacevital.features.learn.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import mx.cruzroja.enlacevital.core.speech.SpeechSynthesizing
import mx.cruzroja.enlacevital.features.learn.data.LessonsService
import mx.cruzroja.enlacevital.features.learn.model.Lesson

class LearnViewModel(private val service: LessonsService) : ViewModel() {
    private val _lessons = MutableStateFlow<List<Lesson>>(emptyList())
    val lessons: StateFlow<List<Lesson>> = _lessons.asStateFlow()

    init {
        viewModelScope.launch {
            try {
                _lessons.value = service.fetchLessons()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _lessons.value = emptyList()
            }
        }
    }
}

class LessonViewModel(val lesson: Lesson, val speech: SpeechSynthesizing) : ViewModel() {
    private val _playback = MutableStateFlow(0f)
    val playback: StateFlow<Float> = _playback.asStateFlow()

    fun setPlayback(value: Float) {
        _playback.value = value
    }

    fun toggleSpeech() {
        if (speech.isSpeaking.value) speech.stop() else speech.speak((listOf(lesson.title) + lesson.steps).joinToString(". "))
    }

    override fun onCleared() {
        speech.stop()
    }
}
