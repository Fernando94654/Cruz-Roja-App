import Foundation

protocol FirstAidAssisting: Sendable {
    // Answers a description of the emergency
    func answer(_ question: String) async -> AssistantAnswer
}

// Mocked assistant: picks a guide by keyword
struct KeywordFirstAidAssistant: FirstAidAssisting {
    var delay: Duration = .seconds(1.4)
    // Latest guides from the server when cached, the bundled ones otherwise
    var guides: @Sendable () -> [FirstAidGuide] = { FirstAidGuide.bundled }

    // Waits briefly so it feels like a search, then answers
    func answer(_ question: String) async -> AssistantAnswer {
        try? await Task.sleep(for: delay)
        return search(question)
    }

    // Picks the guide whose keywords match the text most, or general advice
    func search(_ question: String) -> AssistantAnswer {
        let text = question.lowercased()

        // Each guide scores one point per keyword found in the text; the highest score wins.
        // On a tie the guide listed first keeps the win, and a score of 0 never wins.
        var bestGuide: FirstAidGuide?
        var bestScore = 0
        for guide in guides() where !guide.steps.isEmpty { // a guide without steps can't be followed
            let score = guide.keywords.filter { text.contains($0) }.count
            if score > bestScore {
                bestGuide = guide
                bestScore = score
            }
        }

        guard let guide = bestGuide else {
            return AssistantAnswer(
                text: "No encontré una guía específica. Mantén la calma, revisa que el lugar sea seguro y dime si la persona respira, si sangra o si responde.",
                guide: nil
            )
        }

        return AssistantAnswer(
            text: "Parece un caso de \(guide.title.lowercased()). Primero: \(guide.steps[0].instruction) Te puedo guiar paso a paso por voz mientras llega la ambulancia.",
            guide: guide
        )
    }
}
