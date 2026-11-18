import Foundation
import Testing
@testable import CruzRoja

// Tests the RAG search with the real model and the texts in the app
struct KnowledgeTests {
    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "knowledge-tests-\(UUID().uuidString)")
    }

    @Test func bundledKnowledgeHasEveryChunkWithItsVector() {
        let chunks = KnowledgeCache(directory: temporaryFolder()).load()
        #expect(chunks.count == 32)
        #expect(chunks.allSatisfy { $0.embedding?.count == 768 })
    }

    // Expected ids come from the Hugging Face tokenizer
    @Test func tokenizerMatchesHuggingFace() throws {
        let url = try #require(Bundle.main.url(forResource: "EmbeddingGemma-tokenizer", withExtension: "json"))
        let tokenizer = try BPETokenizer(file: url)
        #expect(tokenizer.encode(tokenizer.queryPrompt + "¿Qué hago si alguien se desangra?")
            == [2, 6639, 157470, 3286, 1088, 887, 6285, 157470, 5962, 19017, 92668, 1716, 40816, 463, 670, 524, 428, 157512, 1])
        #expect(tokenizer.encode(tokenizer.documentPrompt + "Quemaduras\nQué hacer:\n1. Enfría  con agua; no hielo 🚑")
            == [2, 2703, 157470, 6042, 887, 1492, 157470, 67669, 88036, 5, 19017, 8343, 157470, 5, 157453, 157444,
                1948, 919, 2082, 36, 569, 17986, 157475, 749, 114442, 157426, 160110, 1])
    }

    @Test(arguments: [
        ("a mi amigo lo apuñalaron y no para de salir sangre", "hemorragia-grave"),
        ("se quemó con aceite", "quemaduras"),
        ("le picó una abeja y se le hinchó la cara", "anafilaxia"),
        ("lo sacamos de la alberca y no respira", "ahogamiento"),
    ])
    func searchFindsTheRightTopic(question: String, topic: String) async throws {
        let retriever = KnowledgeRetriever(cache: KnowledgeCache(directory: temporaryFolder()))
        let topics = try await retriever.search(question)
        #expect(topics.count == 5)
        #expect(topics.first?.id == topic)
        #expect(topics.first?.chunks.count == 2)
    }

    @Test func rankGroupsChunksByTopic() {
        let chunks = [
            KnowledgeChunk(id: "a-uno", topic: "a", text: "A\nuno", embedding: [1, 0], embeddingModel: "test"),
            KnowledgeChunk(id: "b-uno", topic: "b", text: "B\nuno", embedding: [0.9, 0.1], embeddingModel: "test"),
            KnowledgeChunk(id: "a-dos", topic: "a", text: "A\ndos", embedding: [0, 1], embeddingModel: "test"),
            KnowledgeChunk(id: "c-uno", topic: "c", text: "C\nuno", embedding: [0.5, 0.5], embeddingModel: "test"),
        ]
        let topics = KnowledgeRetriever.rank(chunks, query: [1, 0], k: 2)
        #expect(topics.map(\.id) == ["a", "b"])
        #expect(topics[0].title == "A")
        #expect(topics[0].chunks.map(\.id) == ["a-uno", "a-dos"])
    }

    @Test func withoutAppleModelTheAnswerIsTheWholeTopic() async {
        let assistant = RAGFirstAidAssistant(
            retriever: KnowledgeRetriever(cache: KnowledgeCache(directory: temporaryFolder())),
            fallback: KeywordFirstAidAssistant(delay: .zero), useAppleModel: false)
        let answer = await assistant.answer("se quemó con aceite")
        #expect(answer.text.contains("Cómo reconocerlo:"))
        #expect(answer.text.contains("Qué hacer:"))
        #expect(answer.guide?.id == "burn")
    }

    @Test func topicsWithoutAGuideAnswerWithTextOnly() async {
        let assistant = RAGFirstAidAssistant(
            retriever: KnowledgeRetriever(cache: KnowledgeCache(directory: temporaryFolder())),
            fallback: KeywordFirstAidAssistant(delay: .zero), useAppleModel: false)
        #expect(await assistant.answer("le picó una abeja y se le hinchó la cara").guide == nil)
    }

    @Test func guideMapPointsAtRealTopicsAndGuides() {
        let topics = Set(KnowledgeCache(directory: temporaryFolder()).load()
            .map(\.topic))
        let guides = Set(FirstAidGuide.bundled.map(\.id))
        for (topic, guide) in RAGFirstAidAssistant.guideForTopic {
            #expect(topics.contains(topic), "\(topic)")
            #expect(guides.contains(guide), "\(guide)")
        }
    }

    @Test func withoutKnowledgeItFallsBackToTheKeywordGuides() async {
        let noKnowledge = KnowledgeCache(directory: temporaryFolder(), bundled: nil)
        let assistant = RAGFirstAidAssistant(retriever: KnowledgeRetriever(cache: noKnowledge),
                                             fallback: KeywordFirstAidAssistant(delay: .zero), useAppleModel: false)
        #expect(await assistant.answer("me corté y sangra mucho").guide?.id == "bleeding")
    }
}
