package mx.cruzroja.enlacevital.core.speech

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

interface SpeechSynthesizing {
    val isSpeaking: StateFlow<Boolean>
    val isMuted: StateFlow<Boolean>
    fun setMuted(muted: Boolean)
    fun speak(text: String)
    fun stop()
}

// No-op speech for tests
class SilentSpeech : SpeechSynthesizing {
    private val muted = MutableStateFlow(false)
    override val isSpeaking: StateFlow<Boolean> = MutableStateFlow(false)
    override val isMuted: StateFlow<Boolean> = muted.asStateFlow()
    val spoken = mutableListOf<String>()

    override fun setMuted(muted: Boolean) {
        this.muted.value = muted
    }

    override fun speak(text: String) {
        if (!muted.value) spoken += text
    }

    override fun stop() {}
}
