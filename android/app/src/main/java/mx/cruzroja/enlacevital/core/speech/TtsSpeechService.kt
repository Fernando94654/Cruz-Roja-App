package mx.cruzroja.enlacevital.core.speech

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale
import java.util.UUID

class TtsSpeechService(context: Context) : SpeechSynthesizing {
    private val speaking = MutableStateFlow(false)
    private val muted = MutableStateFlow(false)
    override val isSpeaking: StateFlow<Boolean> = speaking.asStateFlow()
    override val isMuted: StateFlow<Boolean> = muted.asStateFlow()

    private var ready = false
    private val tts: TextToSpeech = TextToSpeech(context.applicationContext) { status ->
        ready = status == TextToSpeech.SUCCESS
        if (ready) configure()
    }

    private fun configure() {
        val mexican = Locale("es", "MX")
        tts.language = if (tts.isLanguageAvailable(mexican) >= TextToSpeech.LANG_AVAILABLE) mexican else Locale("es", "ES")
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                speaking.value = true
            }

            override fun onDone(utteranceId: String?) {
                speaking.value = false
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                speaking.value = false
            }

            override fun onStop(utteranceId: String?, interrupted: Boolean) {
                speaking.value = false
            }
        })
    }

    override fun setMuted(muted: Boolean) {
        this.muted.value = muted
        if (muted) stop()
    }

    override fun speak(text: String) {
        if (muted.value || !ready) return
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())
    }

    override fun stop() {
        if (ready) tts.stop()
        speaking.value = false
    }
}
