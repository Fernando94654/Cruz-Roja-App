import Foundation

// Gemma's BPE tokenizer: turns text into the ids the model understands
struct BPETokenizer: Sendable {
    struct File: Decodable {
        let pieces: [String]
        let merges: [[Int32]]
        let bos: Int32
        let eos: Int32
        let unk: Int32
        let queryPrompt: String
        let documentPrompt: String
        let maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case pieces, merges, bos, eos, unk
            case queryPrompt = "query_prompt"
            case documentPrompt = "document_prompt"
            case maxTokens = "max_tokens"
        }
    }

    let bos: Int32
    let eos: Int32
    let queryPrompt: String
    let documentPrompt: String
    let maxTokens: Int
    // Keyed by bytes because Swift treats some different characters as equal strings
    private let ids: [[UInt8]: Int32]
    // Used for characters that are not in the vocabulary
    private let bytes: [Int32]
    private let merges: [UInt64: (rank: Int, merged: Int32)]

    init(file url: URL) throws {
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        var ids: [[UInt8]: Int32] = [:]
        for (id, piece) in file.pieces.enumerated() {
            ids[Array(piece.utf8)] = Int32(id)
        }
        var merges: [UInt64: (rank: Int, merged: Int32)] = [:]
        for (rank, merge) in file.merges.enumerated() {
            merges[Self.pair(merge[0], merge[1])] = (rank, merge[2])
        }
        self.ids = ids
        self.merges = merges
        bytes = (0...255).map { ids[Array(String(format: "<0x%02X>", $0).utf8)] ?? file.unk }
        bos = file.bos
        eos = file.eos
        queryPrompt = file.queryPrompt
        documentPrompt = file.documentPrompt
        maxTokens = file.maxTokens
    }

    func encode(_ text: String) -> [Int32] {
        // Joins accents with their letter and replaces spaces with Gemma's space symbol
        let normalized = text.precomposedStringWithCanonicalMapping.replacingOccurrences(of: " ", with: "\u{2581}")
        var symbols: [Int32] = []
        for scalar in normalized.unicodeScalars {
            let utf8 = Array(String(scalar).utf8)
            if let id = ids[utf8] {
                symbols.append(id)
            } else {
                symbols += utf8.map { bytes[Int($0)] }
            }
        }
        return [bos] + merged(symbols).prefix(maxTokens - 2) + [eos]
    }

    // Keeps merging the best ranked pair until no pair can be merged
    private func merged(_ initial: [Int32]) -> [Int32] {
        var symbols = initial
        while symbols.count > 1 {
            var best: (index: Int, rank: Int, merged: Int32)?
            for index in 0..<(symbols.count - 1) {
                if let merge = merges[Self.pair(symbols[index], symbols[index + 1])], merge.rank < (best?.rank ?? .max) {
                    best = (index, merge.rank, merge.merged)
                }
            }
            guard let best else { break }
            symbols[best.index] = best.merged
            symbols.remove(at: best.index + 1)
        }
        return symbols
    }

    private static func pair(_ left: Int32, _ right: Int32) -> UInt64 {
        UInt64(UInt32(bitPattern: left)) << 32 | UInt64(UInt32(bitPattern: right))
    }
}
