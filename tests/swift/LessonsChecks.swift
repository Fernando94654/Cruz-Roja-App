import Foundation

// Test-only payloads; the app contains no lesson content or video catalog.
private let fixtureData = try! JSONSerialization.data(withJSONObject:
    ["cardiac_arrest", "choking", "bleeding", "burn"].enumerated().map { index, guideID in
        ["id": String(format: "00000000-0000-4000-8000-%012d", index + 1),
         "title": "Título del servidor", "position": index,
         "guide_id": guideID, "description": NSNull(), "duration_seconds": NSNull(),
         "video_url": "https://www.youtube.com/watch?v=7SBBka5fwW8",
         "publisher": "Editor de prueba \(index)",
         "steps": ["Paso del servidor B", "Paso del servidor A"]] as [String: Any]
    })
private let fixtures = try! JSONDecoder().decode([Lesson].self, from: fixtureData)

private actor RetryService: LessonsServicing {
    var attempts = 0
    func fetchLessons() async throws -> [Lesson] {
        attempts += 1
        if attempts == 1 { throw APIError.offline }
        return fixtures
    }
}

private struct EmptyService: LessonsServicing {
    func fetchLessons() async throws -> [Lesson] { [] }
}

private final class LessonsProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let code = request.url!.host == "missing.test" ? 404 : 200
        let body = code == 404 ? Data("{}".utf8) : fixtureData
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct LessonsChecks {
    @MainActor
    static func main() async throws {
        // The same server UUID survives repeated decoding and both navigation paths.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LessonsProtocol.self]
        let session = URLSession(configuration: configuration)
        let service = LessonsAPIService(client: APIClient(baseURL: URL(string: "https://lessons.test")!, session: session))
        let first = try await service.fetchLessons()[0]
        let again = try await service.fetchLessons()[0]
        assert(first.id == again.id && first.id == fixtures[0].id)
        assert(first.title == "Título del servidor" && first.summary == nil && first.duration == nil)
        assert(first.steps == ["Paso del servidor B", "Paso del servidor A"] && first.publisher == "Editor de prueba 0")
        let missing = LessonsAPIService(client: APIClient(baseURL: URL(string: "https://missing.test")!, session: session))
        do {
            _ = try await missing.fetchLessons()
            assertionFailure("404 must not become an empty or sample catalog")
        } catch { assert(error as? APIError == .invalidResponse) }

        let decoder = JSONDecoder()
        for sample in fixtures {
            let data = try JSONSerialization.data(withJSONObject: [
                "id": sample.id.uuidString, "title": "Otro título", "position": 7,
                "guide_id": sample.guideID!, "duration_seconds": 65,
                "steps": ["Una edición desde la base"], "publisher": "Un editor nuevo"
            ])
            let decoded = try decoder.decode(Lesson.self, from: data)
            assert(decoded.steps == ["Una edición desde la base"] && decoded.id == sample.id
                   && decoded.publisher == "Un editor nuevo")
            assert(decoded.duration == "1:05" && decoded.video == nil)
        }
        let unknown = try decoder.decode(Lesson.self, from: Data("""
        {"id":"00000000-0000-4000-8000-000000000099","title":"RCP","position":0,"guide_id":null,"publisher":null,"steps":[]}
        """.utf8))
        assert(unknown.steps.isEmpty && unknown.video == nil && unknown.publisher == nil)
        do {
            _ = try decoder.decode(Lesson.self, from: Data("{\"title\":\"Sin ID\",\"position\":0}".utf8))
            assertionFailure("Missing UUID must fail, never generate a replacement")
        } catch {}

        for invalid in ["http://www.youtube.com/watch?v=7SBBka5fwW8", "https://youtube.com.evil.test/watch?v=7SBBka5fwW8",
                        "https://user@youtube.com/watch?v=7SBBka5fwW8", "javascript:alert(1)",
                        "https://youtube.com/watch?v=bad", "https://youtube.com/watch?v=7SBBka5fwW8&v=cECkv6xUuTY",
                        "https://youtube.com:444/watch?v=7SBBka5fwW8"] {
            assert(YouTubeVideo(invalid) == nil, invalid)
        }
        assert(YouTubeVideo("https://youtu.be/7SBBka5fwW8")?.id == "7SBBka5fwW8")

        let retry = LearnViewModel(service: RetryService())
        await retry.load()
        assert(retry.errorMessage != nil && retry.lessons.isEmpty && !retry.isLoading)
        await retry.load()
        assert(retry.errorMessage == nil && retry.lessons.count == 4 && retry.hasLoaded)
        let empty = LearnViewModel(service: EmptyService())
        await empty.load()
        assert(empty.hasLoaded && empty.lessons.isEmpty && empty.errorMessage == nil)

        let assistant = KeywordFirstAidAssistant(delay: .zero)
        let phrases = ["no respira", "atragantando", "sangra", "quemó"]
        for (phrase, expected) in zip(phrases, ["cardiac_arrest", "choking", "bleeding", "burn"]) {
            let answer = assistant.search(phrase)
            assert(answer.guide?.id == expected)
            assert(retry.lessons.first { $0.guideID == expected }?.id == fixtures.first { $0.guideID == expected }?.id)
        }
        for phrase in ["convulsiones", "desmayó", "hola"] {
            let guideID = assistant.search(phrase).guide?.id ?? ""
            assert(retry.lessons.first { $0.guideID == guideID } == nil)
        }
        let speech = SilentSpeech()
        let emergency = FirstAidViewModel(assistant: assistant, speech: speech, ambulance: AmbulanceTracker(), lessonsService: RetryService())
        await emergency.lessons.load()
        await emergency.send("sangra")
        assert(emergency.messages.count == 2 && !speech.spoken.isEmpty)
        assert(emergency.lessons.errorMessage != nil) // text/voice survives video backend failure
        emergency.stop()
        let count = speech.spoken.count
        await emergency.send("sangra")
        assert(speech.spoken.count == count) // a late answer cannot speak over video
        let guide = GuideViewModel(guide: FirstAidGuide.catalog[0], speech: speech, ambulance: AmbulanceTracker(), lessonsService: EmptyService())
        guide.stop()
        await guide.runStep()
        assert(speech.spoken.count == count)
        print("Swift lesson checks passed: API decoding, stable UUIDs, database steps/publishers, URLs, retry/empty states, four mappings, independent guidance and speech cleanup.")
    }
}
