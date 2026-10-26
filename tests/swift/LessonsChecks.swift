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

@MainActor
private final class FakeVideoPlayer: LessonVideoPlayback {
    var pauses = 0
    var stops = 0
    var onPlayback: (@MainActor () -> Void)?

    func pause() { pauses += 1 }
    func stop() { stops += 1 }
    func monitorPlayback(onPlayback: @escaping @MainActor () -> Void) async {
        self.onPlayback = onPlayback
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

@MainActor
private final class TrackingSpeech: SpeechSynthesizing {
    var isSpeaking = false
    var isMuted = false
    var stops = 0
    func speak(_ text: String) { isSpeaking = true }
    func stop() { isSpeaking = false; stops += 1 }
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

private actor RecordingProgressService: LessonProgressServicing {
    var server: Set<UUID> = []
    var sent: [[UUID]] = []
    var removed: [UUID] = []
    var fails = false

    func setServer(_ ids: Set<UUID>) { server = ids }
    func setFails(_ value: Bool) { fails = value }

    func complete(_ lessonIDs: [UUID]) async throws -> Set<UUID> {
        if fails { throw APIError.offline }
        sent.append(lessonIDs)
        server.formUnion(lessonIDs)
        return server
    }

    func uncomplete(_ lessonID: UUID) async throws {
        if fails { throw APIError.offline }
        removed.append(lessonID)
        server.remove(lessonID)
    }
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

        let playerSpeech = TrackingSpeech()
        let playerLesson = LessonViewModel(lesson: fixtures[0], speech: playerSpeech)
        var players: [FakeVideoPlayer] = []
        let playerModel = LessonPlayerViewModel(lesson: playerLesson, loadingTimeout: .milliseconds(30)) {
            let player = FakeVideoPlayer()
            players.append(player)
            return player
        }
        playerModel.appear()
        assert(playerModel.isVisible && playerModel.isLoading && !playerModel.isUnavailable)
        let firstRevision = playerModel.revision
        playerModel.didLoad(revision: firstRevision)
        assert(!playerModel.isLoading && !playerModel.isUnavailable)
        playerModel.toggleSpeech()
        assert(playerSpeech.isSpeaking && players.last!.pauses == 1)
        for _ in 0..<100 where players.last!.onPlayback == nil { await Task.yield() }
        assert(players.last!.onPlayback != nil)
        players.last!.onPlayback?()
        assert(!playerSpeech.isSpeaking) // native playback interrupts speech
        try await Task.sleep(for: .milliseconds(45))
        assert(!playerModel.isUnavailable) // successful load cancels the timeout
        playerModel.toggleSpeech()
        playerModel.scenePhaseChanged(isActive: false)
        assert(!playerSpeech.isSpeaking && players.last!.pauses == 3)
        playerModel.toggleSpeech()
        playerModel.openInYouTube()
        assert(!playerSpeech.isSpeaking && players.last!.pauses == 5)

        let oldPlayer = players.last!
        playerModel.didFail(revision: firstRevision)
        assert(playerModel.isUnavailable && !playerModel.isLoading)
        playerModel.retry()
        assert(oldPlayer.stops == 1 && players.count == 3) // initial, appear, retry
        assert(playerModel.isLoading && !playerModel.isUnavailable)
        playerModel.didLoad(revision: firstRevision)
        playerModel.toggleSpeech()
        oldPlayer.onPlayback?()
        assert(playerModel.isLoading && playerSpeech.isSpeaking) // late callbacks cannot change the new session
        playerModel.toggleSpeech()
        try await Task.sleep(for: .milliseconds(60))
        assert(playerModel.isUnavailable && !playerModel.isLoading) // unavailable fallback
        let activePlayer = players.last!
        playerModel.toggleSpeech()
        playerModel.disappear()
        assert(!playerModel.isVisible && activePlayer.stops == 1 && !playerSpeech.isSpeaking)
        playerModel.didLoad(revision: playerModel.revision)
        assert(playerModel.isUnavailable) // hidden player cannot update presentation

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
        let emergency = FirstAidViewModel(assistant: assistant, speech: speech, dictation: SilentDictation(), lessonsService: RetryService())
        await emergency.lessons.load()
        await emergency.send("sangra")
        assert(emergency.messages.count == 2 && !speech.spoken.isEmpty)
        assert(emergency.lessons.errorMessage != nil) // text/voice survives video backend failure
        emergency.stop()
        let count = speech.spoken.count
        await emergency.send("sangra")
        assert(speech.spoken.count == count) // a late answer cannot speak over video
        let guide = GuideViewModel(guide: FirstAidGuide.bundled[0], speech: speech, lessonsService: EmptyService())
        guide.stop()
        await guide.runStep()
        assert(speech.spoken.count == count)
        // Guides: the GET /guides payload decodes, and the cache never leaves the app without guides
        let guidesJSON = Data("""
        [{"id":"allergy","title":"Alergia","icon":"allergens","keywords":["alerg"],"position":0,
          "steps":[{"title":"Llama","instruction":"Pide ayuda.","icon":"phone.fill","seconds":null,"rate":null},
                   {"title":"Comprime","instruction":"Fuerte.","icon":"heart","seconds":18,"rate":110}]}]
        """.utf8)
        let served = try decoder.decode([FirstAidGuide].self, from: guidesJSON)
        assert(served[0].steps[1].rate == 110 && served[0].steps[0].seconds == nil)
        let cacheFolder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let guideCache = GuideCache(directory: cacheFolder)
        assert(guideCache.load() == FirstAidGuide.bundled) // nothing cached yet
        guideCache.save([])
        assert(guideCache.load() == FirstAidGuide.bundled) // an empty answer is ignored
        guideCache.save(served)
        assert(guideCache.load().map(\.id) == ["allergy"])
        let cachedAssistant = KeywordFirstAidAssistant(delay: .zero, guides: { guideCache.load() })
        assert(cachedAssistant.search("tiene una alergia").guide?.id == "allergy")
        assert(cachedAssistant.search("sangra").guide == nil) // only the server's guides are searched
        try? FileManager.default.removeItem(at: cacheFolder)

        // Lesson progress: local first, synced only while signed in
        let suite = "lesson-progress-checks-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LessonProgressStore(defaults: defaults)
        let remote = RecordingProgressService()
        var signedIn = false
        let progress = LessonProgress(service: remote, store: store, isSignedIn: { signedIn })
        await progress.toggle(fixtures[0])
        assert(progress.isCompleted(fixtures[0]) && store.completed == [fixtures[0].id])
        let sentSignedOut = await remote.sent
        assert(sentSignedOut.isEmpty) // signed out: nothing leaves the device
        await progress.toggle(fixtures[1])
        await progress.toggle(fixtures[1]) // undone while signed out
        assert(store.completed == [fixtures[0].id] && store.pendingRemovals == [fixtures[1].id])

        signedIn = true
        await remote.setServer([fixtures[1].id, fixtures[2].id]) // completed on another phone
        await progress.sync()
        let removed = await remote.removed, sent = await remote.sent
        assert(removed == [fixtures[1].id]) // the local undo reaches the server
        assert(sent == [[fixtures[0].id]])
        assert(progress.completed == [fixtures[0].id, fixtures[2].id] && store.completed == progress.completed)
        assert(store.pendingRemovals.isEmpty && progress.completedCount(in: fixtures) == 2)

        await remote.setFails(true)
        await progress.toggle(fixtures[3])
        assert(progress.isCompleted(fixtures[3]) && store.completed.contains(fixtures[3].id)) // offline keeps the tap
        await remote.setFails(false)
        let learn = LearnViewModel(service: RetryService(), progress: progress)
        await learn.load()
        await learn.load()
        let server = await remote.server
        assert(server.contains(fixtures[3].id)) // loading the list retries the sync

        store.clear() // what signing out does
        signedIn = false
        await progress.sync()
        assert(progress.completed.isEmpty)
        let lessonModel = LessonViewModel(lesson: fixtures[0], speech: TrackingSpeech(), progress: progress)
        await lessonModel.toggleCompletion()
        assert(lessonModel.isCompleted && progress.isCompleted(fixtures[0]))
        assert(!LessonViewModel(lesson: fixtures[0], speech: TrackingSpeech()).isCompleted)

        print("Swift lesson checks passed: API decoding, stable UUIDs, database steps/publishers, URLs, player lifecycle/retry/timeout/speech, lesson retry/empty states, four mappings, independent guidance and speech cleanup, served/cached guides, local-first lesson progress and sync.")
    }
}
