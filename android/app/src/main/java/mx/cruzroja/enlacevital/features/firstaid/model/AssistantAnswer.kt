package mx.cruzroja.enlacevital.features.firstaid.model

import java.util.UUID

data class SourceExcerpt(val document: String, val page: Int, val excerpt: String)

data class AssistantAnswer(
    val text: String,
    val guide: FirstAidGuide?,
    val sources: List<SourceExcerpt>,
    val id: String = UUID.randomUUID().toString(),
)

sealed interface ChatMessage {
    val id: String

    data class User(val text: String, override val id: String = UUID.randomUUID().toString()) : ChatMessage

    data class Assistant(val answer: AssistantAnswer) : ChatMessage {
        override val id: String get() = answer.id
    }
}
