package mx.cruzroja.enlacevital.features.firstaid.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.cruzroja.enlacevital.core.speech.SpeechSynthesizing
import mx.cruzroja.enlacevital.features.emergency.data.AmbulanceTracker
import mx.cruzroja.enlacevital.features.firstaid.data.FirstAidAssistant
import mx.cruzroja.enlacevital.features.firstaid.model.AssistantAnswer
import mx.cruzroja.enlacevital.features.firstaid.model.ChatMessage
import mx.cruzroja.enlacevital.features.firstaid.model.FirstAidGuide

data class FirstAidUiState(
    val draft: String = "",
    val messages: List<ChatMessage> = emptyList(),
    val isThinking: Boolean = false,
    val isListening: Boolean = false,
) {
    val hasDraft: Boolean get() = draft.isNotBlank()
}

class FirstAidViewModel(
    private val assistant: FirstAidAssistant,
    val speech: SpeechSynthesizing,
    val ambulance: AmbulanceTracker,
    messages: List<ChatMessage> = emptyList(),
) : ViewModel() {
    private val _state = MutableStateFlow(FirstAidUiState(messages = messages))
    val state: StateFlow<FirstAidUiState> = _state.asStateFlow()

    val suggestions = listOf(
        "Mi papá no respira y no responde",
        "Un niño se está atragantando",
        "Me corté y sangra mucho",
        "Se quemó con aceite",
    )
    val guides: List<FirstAidGuide> = FirstAidGuide.CATALOG

    init {
        ambulance.request()
    }

    fun setDraft(text: String) = _state.update { it.copy(draft = text) }

    fun stop() = speech.stop()

    fun reset() {
        speech.stop()
        _state.update { it.copy(messages = emptyList()) }
    }

    fun send(text: String) {
        val question = text.trim()
        if (question.isEmpty() || _state.value.isThinking) return
        _state.update { it.copy(draft = "", messages = it.messages + ChatMessage.User(question), isThinking = true) }
        viewModelScope.launch {
            val answer = assistant.answer(question)
            _state.update { it.copy(messages = it.messages + ChatMessage.Assistant(answer), isThinking = false) }
            speech.speak(answer.text)
        }
    }

    // Fixed phrase until on-device speech recognition exists
    fun dictate() {
        speech.stop()
        _state.update { it.copy(isListening = true) }
        viewModelScope.launch {
            delay(2000)
            _state.update { it.copy(isListening = false) }
            send("Mi abuela se desmayó y está mareada")
        }
    }

    fun toggleSpeech(answer: AssistantAnswer) {
        if (speech.isSpeaking.value) speech.stop() else speech.speak(answer.text)
    }

    override fun onCleared() {
        speech.stop()
    }
}
