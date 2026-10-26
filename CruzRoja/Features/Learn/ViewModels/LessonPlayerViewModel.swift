import Foundation
import Observation

@MainActor
protocol LessonVideoPlayback: AnyObject {
    // Pauses the video without unloading it
    func pause()
    // Unloads the video
    func stop()
    // Calls back whenever the video starts playing
    func monitorPlayback(onPlayback: @escaping @MainActor () -> Void) async
}

/// Owns the video session and coordinates it with the lesson's speech.
@MainActor
@Observable
final class LessonPlayerViewModel<Player: LessonVideoPlayback> {
    private let lesson: LessonViewModel
    @ObservationIgnored private let makePlayer: () -> Player
    @ObservationIgnored private let loadingTimeout: Duration
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    private(set) var player: Player
    private(set) var isVisible = false
    private(set) var revision = 0
    private(set) var isLoading = true
    private(set) var isUnavailable = false

    // Creates the first player right away; makePlayer lets tests use a fake
    init(lesson: LessonViewModel, loadingTimeout: Duration = .seconds(20),
         makePlayer: @escaping () -> Player) {
        self.lesson = lesson
        self.loadingTimeout = loadingTimeout
        self.makePlayer = makePlayer
        self.player = makePlayer()
    }

    // Starts a fresh player session when the lesson opens
    func appear() {
        lesson.stop()
        replacePlayer()
        isVisible = true
        startTasks()
    }

    // Unloads the player and stops speech when leaving the lesson
    func disappear() {
        isVisible = false
        cancelTasks()
        lesson.stop()
        player.stop()
    }

    // Reloads the player after a failure or timeout
    func retry() {
        guard isVisible else { return }
        replacePlayer()
        startTasks()
    }

    // Marks the video ready, ignoring callbacks from older sessions
    func didLoad(revision loadedRevision: Int) {
        guard isVisible, revision == loadedRevision else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        isLoading = false
        isUnavailable = false
    }

    // Shows the fallback, ignoring callbacks from older sessions
    func didFail(revision failedRevision: Int) {
        guard isVisible, revision == failedRevision else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        isLoading = false
        isUnavailable = true
    }

    // Pauses the video before reading the lesson aloud
    func toggleSpeech() {
        player.pause()
        lesson.toggleSpeech()
    }

    // Stops speech and video before handing off to YouTube
    func openInYouTube() {
        lesson.stop()
        player.pause()
    }

    // Pauses everything when the app goes to the background
    func scenePhaseChanged(isActive: Bool) {
        guard !isActive else { return }
        player.pause()
        lesson.stop()
    }

    // Throws away the current player and starts a new session
    private func replacePlayer() {
        cancelTasks()
        player.stop()
        player = makePlayer()
        revision += 1
        isLoading = true
        isUnavailable = false
    }

    // Watches playback to stop speech, and starts the loading timeout
    private func startTasks() {
        guard lesson.lesson.video != nil else { return }
        let currentRevision = revision
        let currentPlayer = player
        let timeout = loadingTimeout
        monitorTask = Task { [weak self] in
            await currentPlayer.monitorPlayback { [weak self] in
                guard let self, self.isVisible, self.revision == currentRevision else { return }
                self.lesson.stop()
            }
        }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.didTimeout(revision: currentRevision)
        }
    }

    // Shows the fallback if the video is still loading
    private func didTimeout(revision timedOutRevision: Int) {
        guard isVisible, revision == timedOutRevision, isLoading else { return }
        isLoading = false
        isUnavailable = true
    }

    // Stops the playback watcher and the timeout
    private func cancelTasks() {
        monitorTask?.cancel()
        monitorTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
