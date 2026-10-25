//
//  CruzRojaTestsAprende.swift
//  CruzRojaTestsAprende
//
//  Created by Luis on 25/10/26.
//

import Foundation
import Testing
@testable import CruzRoja

// Test-only payloads; the app contains no lesson content or video catalog.
private let fixtureData = try! JSONSerialization.data(withJSONObject:
    ["cardiac_arrest", "choking", "bleeding", "burn"].enumerated().map { index, guideID in
        ["id": String(format: "00000000-0000-4000-8000-%012d", index + 1),
         "title": "Título del servidor", "position": index,
         "guide_id": guideID, "video_url": "https://www.youtube.com/watch?v=7SBBka5fwW8",
         "publisher": "Editor de prueba \(index)", "steps": ["Paso A", "Paso B"]] as [String: Any]
    })
private let fixtures = try! JSONDecoder().decode([Lesson].self, from: fixtureData)

// Fails the first fetch, then returns the fixtures
private actor RetryService: LessonsServicing {
    var attempts = 0
    func fetchLessons() async throws -> [Lesson] {
        attempts += 1
        if attempts == 1 { throw APIError.offline }
        return fixtures
    }
}

// Progress server kept in memory
private actor RecordingProgressService: LessonProgressServicing {
    var server: Set<UUID> = []
    var sent: [[UUID]] = []
    var removed: [UUID] = []

    func setServer(_ ids: Set<UUID>) { server = ids }

    func complete(_ lessonIDs: [UUID]) async throws -> Set<UUID> {
        sent.append(lessonIDs)
        server.formUnion(lessonIDs)
        return server
    }

    func uncomplete(_ lessonID: UUID) async throws {
        removed.append(lessonID)
        server.remove(lessonID)
    }
}

@MainActor
struct CruzRojaTestsAprende {
    @Test("Si falla la carga de lecciones se muestra error y Reintentar las recupera")
    func lessonsRetryAfterError() async {
        let viewModel = LearnViewModel(service: RetryService())
        await viewModel.load()
        #expect(viewModel.errorMessage != nil && viewModel.lessons.isEmpty && !viewModel.isLoading)
        await viewModel.load()
        #expect(viewModel.errorMessage == nil && viewModel.lessons.count == 4 && viewModel.hasLoaded)
    }

    @Test("Marcar como completada se guarda sin sesión y se sincroniza al iniciar sesión")
    func lessonProgressSyncs() async {
        let remote = RecordingProgressService()
        let store = LessonProgressStore(defaults: UserDefaults(suiteName: "aprende-tests-\(UUID().uuidString)")!)
        var signedIn = false
        let progress = LessonProgress(service: remote, store: store, isSignedIn: { signedIn })

        let lesson = LessonViewModel(lesson: fixtures[0], speech: SilentSpeech(), progress: progress)
        await lesson.toggleCompletion()
        await progress.toggle(fixtures[1])
        await progress.toggle(fixtures[1]) // undone while signed out
        #expect(lesson.isCompleted && store.completed == [fixtures[0].id])
        #expect(await remote.sent.isEmpty) // signed out: nothing leaves the device

        signedIn = true
        await remote.setServer([fixtures[1].id, fixtures[2].id]) // completed on another phone
        await progress.sync()
        #expect(await remote.removed == [fixtures[1].id])
        #expect(progress.completed == [fixtures[0].id, fixtures[2].id])
        #expect(progress.completedCount(in: fixtures) == 2)
    }

    @Test("\"Mi abuela se desmayó\" da la guía de desmayo por voz aunque falle el video")
    func emergencyScenarioGivesGuide() async {
        let speech = SilentSpeech()
        let emergency = FirstAidViewModel(assistant: KeywordFirstAidAssistant(delay: .zero), speech: speech,
                                          lessonsService: RetryService())
        await emergency.lessons.load() // the video catalog fails
        await emergency.send("Mi abuela se desmayó y está mareada")

        guard case .assistant(let answer) = emergency.messages.last else {
            Issue.record("The assistant did not answer")
            return
        }
        #expect(answer.guide?.id == "fainting")
        #expect(speech.spoken == [answer.text])
        #expect(emergency.lessons.errorMessage != nil)
    }
}
