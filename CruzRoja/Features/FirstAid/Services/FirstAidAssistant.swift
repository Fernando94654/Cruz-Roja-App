import Foundation

protocol FirstAidAssisting: Sendable {
    func answer(_ question: String) async -> AssistantAnswer
}

// Keyword search standing in for the RAG over Cruz Roja manuals
struct KeywordFirstAidAssistant: FirstAidAssisting {
    let manual = "Manual de Primeros Auxilios (demo)"
    var delay: Duration = .seconds(1.4)
    // Latest guides from the server when cached, the bundled ones otherwise
    var guides: @Sendable () -> [FirstAidGuide] = { FirstAidGuide.bundled }

    func answer(_ question: String) async -> AssistantAnswer {
        try? await Task.sleep(for: delay)
        return search(question)
    }

    func search(_ question: String) -> AssistantAnswer {
        let text = question.lowercased()
        let match = guides()
            .map { guide in (guide, guide.keywords.filter { text.contains($0) }.count) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0

        guard let guide = match else {
            return AssistantAnswer(
                text: "No encontré una guía específica. Mantén la calma, revisa que el lugar sea seguro y dime si la persona respira, si sangra o si responde.",
                guide: nil,
                sources: [SourceExcerpt(document: manual, page: 8, excerpt: "Revisar, llamar y atender.")]
            )
        }

        let sources = guide.steps.prefix(2).enumerated().map { i, step in
            SourceExcerpt(document: manual, page: guide.manualPage.map { $0 + i }, excerpt: step.instruction)
        }
        return AssistantAnswer(
            text: "Parece un caso de \(guide.title.lowercased()). Primero: \(guide.steps[0].instruction) Te puedo guiar paso a paso por voz mientras llega la ambulancia.",
            guide: guide,
            sources: sources
        )
    }
}
