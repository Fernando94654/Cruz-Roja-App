package mx.cruzroja.enlacevital

import mx.cruzroja.enlacevital.features.firstaid.data.KeywordFirstAidAssistant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class KeywordFirstAidAssistantTest {
    private val assistant = KeywordFirstAidAssistant(delayMillis = 0)

    @Test
    fun matchesTheGuideWithMostKeywords() {
        assertEquals("bleeding", assistant.search("Me corté y sangra mucho").guide?.id)
        assertEquals("cardiac_arrest", assistant.search("Mi papá no respira y no responde").guide?.id)
        assertEquals(2, assistant.search("Se quemó con aceite").sources.size)
    }

    @Test
    fun fallsBackWhenNothingMatches() {
        val answer = assistant.search("hola")
        assertNull(answer.guide)
        assertEquals(1, answer.sources.size)
    }
}
