// Measures how often the app's search finds the right topic, with and without Apple's model picking.
// Run it from the repo root on a Mac:
//   xcrun swiftc -O CruzRoja/Features/Assistant/Services/{Embedder,BPETokenizer,KnowledgeRetriever,KnowledgeCache,TopicPicker}.swift \
//       CruzRoja/Features/Assistant/Models/Knowledge.swift CruzRoja/Core/Logging/Log.swift tools/evaluate-rag/main.swift -o /tmp/evaluate-rag
//   /tmp/evaluate-rag
import CoreML
import Foundation

struct Question: Decodable {
    let q: String
    let topic: String
    let also: [String]?

    func isRight(_ topic: String) -> Bool { topic == self.topic || (also ?? []).contains(topic) }
}

// Exact McNemar test: how likely this many fixed vs broken answers is if both ways were equally good
func mcnemar(fixed: Int, broke: Int) -> Double {
    let n = fixed + broke
    guard n > 0 else { return 1 }
    var tail = 0.0
    for i in 0...min(fixed, broke) {
        tail += exp(lgamma(Double(n + 1)) - lgamma(Double(i + 1)) - lgamma(Double(n - i + 1))) / pow(2, Double(n))
    }
    return min(1, 2 * tail)
}

let resources = URL(fileURLWithPath: "CruzRoja/Resources")
let model = try MLModel.compileModel(at: resources.appending(path: "EmbeddingGemma.mlpackage"))
let embedder = try Embedder(model: model, tokenizer: resources.appending(path: "EmbeddingGemma-tokenizer.json"))
let chunks = KnowledgeCache(directory: FileManager.default.temporaryDirectory,
                            bundled: resources.appending(path: "knowledge.json")).load()

for file in ["retrieval_eval.json", "retrieval_test.json"] {
    let url = URL(fileURLWithPath: "tools/embedding-model").appending(path: file)
    let questions = try JSONDecoder().decode([Question].self, from: Data(contentsOf: url))
    var searchHits = 0, pickHits = 0, fixed = 0, broke = 0
    var misses: [String] = []
    for question in questions {
        let topics = KnowledgeRetriever.rank(chunks, query: try embedder.embedQuery(question.q), k: 5)
        let index = await TopicPicker.pick(question.q, titles: topics.map(\.title)) ?? 0
        let searchRight = question.isRight(topics[0].id)
        let pickRight = question.isRight(topics[index].id)
        searchHits += searchRight ? 1 : 0
        pickHits += pickRight ? 1 : 0
        fixed += !searchRight && pickRight ? 1 : 0
        broke += searchRight && !pickRight ? 1 : 0
        if !pickRight { misses.append("  \(question.q) -> \(topics[index].id) (want \(question.topic))") }
    }
    print("\(file) (\(questions.count) questions)")
    print("  search only: \(searchHits)/\(questions.count)")
    print("  with pick:   \(pickHits)/\(questions.count)  fixed \(fixed), broke \(broke), p = \(String(format: "%.4f", mcnemar(fixed: fixed, broke: broke)))")
    print(misses.joined(separator: "\n"))
}
