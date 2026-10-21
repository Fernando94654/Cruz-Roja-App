package mx.cruzroja.enlacevital.features.firstaid.data

import kotlinx.coroutines.delay
import mx.cruzroja.enlacevital.features.firstaid.model.AssistantAnswer
import mx.cruzroja.enlacevital.features.firstaid.model.FirstAidGuide
import mx.cruzroja.enlacevital.features.firstaid.model.SourceExcerpt

interface FirstAidAssistant {
    suspend fun answer(question: String): AssistantAnswer
}

// Keyword search standing in for the RAG over Cruz Roja manuals
class KeywordFirstAidAssistant(private val delayMillis: Long = 1400) : FirstAidAssistant {
    private val manual = "Manual de Primeros Auxilios (demo)"

    override suspend fun answer(question: String): AssistantAnswer {
        delay(delayMillis)
        return search(question)
    }

    fun search(question: String): AssistantAnswer {
        val text = question.lowercase()
        val guide = FirstAidGuide.CATALOG
            .map { guide -> guide to guide.keywords.count { text.contains(it) } }
            .filter { it.second > 0 }
            .maxByOrNull { it.second }
            ?.first
            ?: return AssistantAnswer(
                text = "No encontré una guía específica. Mantén la calma, revisa que el lugar sea seguro y dime si la persona respira, si sangra o si responde.",
                guide = null,
                sources = listOf(SourceExcerpt(manual, 8, "Revisar, llamar y atender.")),
            )

        val sources = guide.steps.take(2).mapIndexed { i, step -> SourceExcerpt(manual, guide.manualPage + i, step.instruction) }
        return AssistantAnswer(
            text = "Parece un caso de ${guide.title.lowercase()}. Primero: ${guide.steps[0].instruction} Te puedo guiar paso a paso por voz mientras llega la ambulancia.",
            guide = guide,
            sources = sources,
        )
    }
}
