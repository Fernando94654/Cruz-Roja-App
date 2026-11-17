import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Finds the closest texts and Apple's model answers with them.
// Without the model it shows the closest text, and if search fails it uses the keywords.
struct RAGFirstAidAssistant: FirstAidAssisting {
    let retriever: KnowledgeRetriever
    let fallback: KeywordFirstAidAssistant
    var useAppleModel = true

    static let instructions = """
        Eres el asistente de primeros auxilios de la Cruz Roja Mexicana. Hablas con una persona sin \
        entrenamiento que está frente a una emergencia. Responde solo con la información de las referencias \
        que recibes; no inventes pasos, dosis, números ni datos. Si las referencias no responden la pregunta, \
        dilo y recomienda llamar al 911. Si las referencias indican llamar al 911, empieza con "Llama al 911". \
        Responde en español de México, hablando de tú, en máximo 6 pasos cortos y numerados.
        """

    // Guide and video for each topic; topics not listed don't have one yet
    static let guideForTopic = [
        "paro-cardiaco-rcp-adulto": "cardiac_arrest",
        "rcp-ninos-bebes": "cardiac_arrest",
        "atragantamiento-adulto-nino": "choking",
        "atragantamiento-bebe": "choking",
        "hemorragia-grave": "bleeding",
        "quemaduras": "burn",
        "convulsiones": "seizure",
        "inconsciente-respira": "fainting",
    ]

    func answer(_ question: String) async -> AssistantAnswer {
        guard let chunks = try? await retriever.search(question), let closest = chunks.first else {
            return fallback.search(question)
        }
        let guide = guide(for: closest)
        if useAppleModel, let text = await askAppleModel(question, chunks) {
            return AssistantAnswer(text: text, guide: guide)
        }
        return AssistantAnswer(text: closest.text, guide: guide)
    }

    // Removes the last part of the id to get the topic
    private func guide(for chunk: KnowledgeChunk) -> FirstAidGuide? {
        let topic = chunk.id.split(separator: "-").dropLast().joined(separator: "-")
        guard let id = Self.guideForTopic[topic] else { return nil }
        return fallback.guides().first { $0.id == id && !$0.steps.isEmpty }
    }

    // Returns nil if the phone doesn't have the model or it fails
    private func askAppleModel(_ question: String, _ chunks: [KnowledgeChunk]) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }
        // The default filters block topics like wounds and blood
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        guard model.isAvailable else { return nil }
        let references = chunks.enumerated().map { "[\($0.offset + 1)] \($0.element.text)" }.joined(separator: "\n\n")
        // New session for each question so the context doesn't fill up
        let session = LanguageModelSession(model: model, instructions: Self.instructions)
        let answer = try? await session.respond(to: "Referencias:\n\(references)\n\nPregunta: \(question)").content
        let text = answer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
        #else
        return nil
        #endif
    }
}
