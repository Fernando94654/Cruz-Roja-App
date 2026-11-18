import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Apple's model picks which of the found topics fits the question best
enum TopicPicker {
    static let instructions = """
        Clasificas emergencias de primeros auxilios. Lee la situación y elige el tema que mejor la describe. \
        Responde solo con el número del tema.
        """

    // Returns the index of the chosen title, or nil if the phone doesn't have the model or it fails
    static func pick(_ question: String, titles: [String]) async -> Int? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else { return nil }
        // The default filters block topics like wounds and blood
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        guard model.isAvailable else { return nil }
        let list = titles.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let session = LanguageModelSession(model: model, instructions: instructions)
        let prompt = "Situación: \(question)\n\nTemas:\n\(list)\n\nNúmero del tema:"
        guard let answer = try? await session.respond(to: prompt, options: GenerationOptions(samplingMode: .greedy)).content,
              let number = Int(String(answer.drop { !$0.isNumber }.prefix { $0.isNumber })),
              number >= 1, number <= titles.count else { return nil }
        return number - 1
        #else
        return nil
        #endif
    }
}
