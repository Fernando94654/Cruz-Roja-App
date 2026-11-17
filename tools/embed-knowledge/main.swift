// Computes the vectors on a Mac with the same code as the app, so they match the phone.
// Reads a list of id and text from stdin and prints the vectors as JSON.
import CoreML
import Foundation

struct Item: Decodable {
    let id: String
    let text: String
}

struct Output: Encodable {
    let model: String
    let vectors: [String: [Float]]
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("Usage: embed-knowledge <model.mlpackage> <tokenizer.json> [--query]")
    exit(1)
}
let items = try JSONDecoder().decode([Item].self, from: FileHandle.standardInput.readDataToEndOfFile())
let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: arguments[1]))
let embedder = try Embedder(model: compiled, tokenizer: URL(fileURLWithPath: arguments[2]))
let asQuestions = arguments.contains("--query")

var vectors: [String: [Float]] = [:]
for item in items {
    vectors[item.id] = asQuestions ? try embedder.embedQuery(item.text) : try embedder.embedDocument(item.text)
}
FileHandle.standardOutput.write(try JSONEncoder().encode(Output(model: embedder.identifier, vectors: vectors)))
