import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Finds the closest topics, Apple's model picks the best one and answers with its texts.
// Without the model it shows the closest topic, and if search fails it uses the keywords.
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
        guard let topics = try? await retriever.search(question), var best = topics.first else {
            return fallback.search(question)
        }
        if useAppleModel, let index = await TopicPicker.pick(question, titles: topics.map(\.title)) {
            best = topics[index]
        }
        let guide = guide(for: best.id)
        // The chosen topic first, then the next best one in case the pick was wrong
        let backup = topics.first { $0.id != best.id }?.chunks ?? []
        if useAppleModel, let text = await askAppleModel(question, best.chunks + backup) {
            return AssistantAnswer(text: text, guide: guide)
        }
        // Without the model show the whole topic so the steps are always there
        return AssistantAnswer(text: best.chunks.map(\.text).joined(separator: "\n\n"), guide: guide)
    }

    private func guide(for topic: String) -> FirstAidGuide? {
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
