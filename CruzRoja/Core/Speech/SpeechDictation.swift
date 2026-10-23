import AVFoundation
import Speech

// Spanish (Mexico) dictation with SFSpeechRecognizer
@MainActor
@Observable
final class SpeechDictation: Dictating {
    private(set) var isListening = false

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var hasTap = false
    @ObservationIgnored private var startID: UUID?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?

    func start(onText: @escaping @MainActor (String) -> Void,
               onError: @escaping @MainActor (String) -> Void) async throws {
        guard startID == nil else { throw DictationError.alreadyListening }
        let id = UUID()
        startID = id
        defer { if startID == id && !isListening { startID = nil } }

        try await Self.authorize()
        guard startID == id, !Task.isCancelled else { throw CancellationError() }
        guard let recognizer, recognizer.isAvailable else { throw DictationError.unavailable }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw DictationError.unavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        audioEngine = engine
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasTap = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            stop()
            throw error
        }
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let done = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                guard self?.startID == id, self?.isListening == true else { return }
                if let text { onText(text) }
                if done {
                    self?.stop()
                    if let error, text == nil { onError("El dictado se interrumpió: \(error.localizedDescription)") }
                }
            }
        }
    }

    func stop() {
        startID = nil
        guard let engine = audioEngine else { return }
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0) }
        hasTap = false
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        audioEngine = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func authorize() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            let granted = try await requestPermission(timeoutError: .speechPermissionTimedOut) { complete in
                SFSpeechRecognizer.requestAuthorization { complete($0 == .authorized) }
            }
            guard granted else { throw DictationError.notAuthorized }
        case .denied, .restricted:
            throw DictationError.notAuthorized
        @unknown default:
            throw DictationError.notAuthorized
        }

        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .undetermined:
            let granted = try await requestPermission(timeoutError: .microphonePermissionTimedOut) { complete in
                AVAudioApplication.requestRecordPermission(completionHandler: complete)
            }
            guard granted else { throw DictationError.notAuthorized }
        case .denied:
            throw DictationError.notAuthorized
        @unknown default:
            throw DictationError.notAuthorized
        }
    }

    private static func requestPermission(timeoutError: DictationError,
                                          _ request: (@escaping @Sendable (Bool) -> Void) -> Void) async throws -> Bool {
        let response = await withCheckedContinuation { (continuation: CheckedContinuation<Bool?, Never>) in
            let reply = PermissionReply(continuation)
            request { granted in
                Task { @MainActor in reply.finish(granted) }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(15))
                reply.finish(nil)
            }
        }
        guard let response else { throw timeoutError }
        return response
    }
}

@MainActor
private final class PermissionReply {
    private var continuation: CheckedContinuation<Bool?, Never>?

    init(_ continuation: CheckedContinuation<Bool?, Never>) {
        self.continuation = continuation
    }

    func finish(_ value: Bool?) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
