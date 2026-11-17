import CoreML
import Foundation

// Turns a text into a vector of 768 numbers with EmbeddingGemma
final class Embedder {
    let identifier: String
    private let model: MLModel
    private let tokenizer: BPETokenizer

    struct NoOutput: Error {}

    init(model url: URL, tokenizer tokenizerURL: URL) throws {
        // CPU only because the model needs float32
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuOnly
        model = try MLModel(contentsOf: url, configuration: configuration)
        tokenizer = try BPETokenizer(file: tokenizerURL)
        let metadata = model.modelDescription.metadata[.creatorDefinedKey] as? [String: String]
        identifier = metadata?["identifier"] ?? "EmbeddingGemma"
    }

    static func bundled() -> Embedder? {
        guard let model = Bundle.main.url(forResource: "EmbeddingGemma", withExtension: "mlmodelc"),
              let tokenizer = Bundle.main.url(forResource: "EmbeddingGemma-tokenizer", withExtension: "json") else { return nil }
        return try? Embedder(model: model, tokenizer: tokenizer)
    }

    // The model was trained with a different prefix for questions and for texts
    func embedQuery(_ question: String) throws -> [Float] {
        try embed(tokenizer.queryPrompt + question)
    }

    func embedDocument(_ text: String) throws -> [Float] {
        try embed(tokenizer.documentPrompt + text)
    }

    private func embed(_ text: String) throws -> [Float] {
        let ids = tokenizer.encode(text)
        let shape = [1, NSNumber(value: ids.count)]
        let inputIDs = try MLMultiArray(shape: shape, dataType: .int32)
        let mask = try MLMultiArray(shape: shape, dataType: .int32)
        for (index, id) in ids.enumerated() {
            inputIDs[index] = NSNumber(value: id)
            mask[index] = 1
        }
        let input = try MLDictionaryFeatureProvider(dictionary: ["input_ids": inputIDs, "attention_mask": mask])
        guard let output = try model.prediction(from: input).featureValue(for: "embedding")?.multiArrayValue else {
            throw NoOutput()
        }
        return (0..<output.count).map { output[$0].floatValue }
    }
}
