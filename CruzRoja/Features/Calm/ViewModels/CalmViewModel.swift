import Foundation
import Observation

@MainActor
@Observable
final class CalmViewModel {
    private(set) var stage: CalmStage = .intake
    // Lo que entendio la IA al inicio y la tecnica que se esta usando
    private(set) var assessment: CalmAssessment?
    private(set) var technique: CalmTechnique = .breathing
    private(set) var isAssessing = false

    // Fase y ciclo actuales de la respiracion; breathCount cambia en cada fase para animar el circulo
    private(set) var phase: BreathPhase = .inhale
    private(set) var cycle = 1
    private(set) var breathCount = 0
    // Cambia cada vez que empieza una respiracion; la vista lo usa para arrancarla
    private(set) var breathingRun = 0

    private(set) var messages: [CalmMessage] = []
    // Paso de la tecnica que se esta respondiendo
    private(set) var stepIndex = 0
    private(set) var concerns: Set<SafetyConcern> = []
    private(set) var isReplying = false
    private(set) var dictationError: String?
    var draft = ""

    // Calificacion final y plan para la proxima vez
    private(set) var lastRating: Int?
    private(set) var plan: CalmPlan?
    private(set) var isPlanning = false
    private(set) var history: [CalmCheckIn]

    let pattern: BreathingPattern
    private var intake = ""
    private let companion: CalmCompanioning
    private let speech: SpeechSynthesizing
    private let dictation: Dictating
    private let haptics: BreathHaptics
    private let store: CalmHistoryStoring
    private let sleep: @MainActor (Duration) async throws -> Void

    // Sin dependencias usa la IA del dispositivo, la voz y el microfono reales; las pruebas pasan las suyas
    init(pattern: BreathingPattern = .standard,
         companion: CalmCompanioning? = nil,
         speech: SpeechSynthesizing? = nil,
         dictation: Dictating? = nil,
         haptics: BreathHaptics? = nil,
         store: CalmHistoryStoring? = nil,
         sleep: (@MainActor (Duration) async throws -> Void)? = nil) {
        self.pattern = pattern
        self.companion = companion ?? FallbackCalmCompanion()
        self.speech = speech ?? SpeechService()
        self.dictation = dictation ?? SpeechDictation()
        self.haptics = haptics ?? DeviceBreathHaptics()
        let store = store ?? UserDefaultsCalmHistory()
        self.store = store
        self.history = store.load()
        self.sleep = sleep ?? { try await Task.sleep(for: $0) }
    }

    var isVoiceOn: Bool { !speech.isMuted }
    var isListening: Bool { dictation.isListening }
    var steps: [CalmStep] { technique.steps }
    var currentStep: CalmStep? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    var hasFinishedSteps: Bool { currentStep == nil }
    // Segundos de la fase actual, para la animacion del circulo
    var phaseSeconds: Double { pattern.seconds(of: phase) }

    // MARK: Inicio

    func onAppear() {
        companion.prewarm()
    }

    // La IA entiende lo que cuenta la persona y elige la tecnica; las señales de riesgo se revisan antes
    func submitIntake() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isAssessing else { return }
        stopListening()
        draft = ""
        intake = text

        let found = CalmSafety.concerns(in: text)
        if !found.isEmpty {
            // Mientras se pide ayuda, lo mas seguro es respirar
            concerns.formUnion(found)
            assessment = CalmAssessment(intensity: nil, trigger: "", technique: .breathing,
                                        message: CalmSafety.message(for: found), source: .rules)
            start(.breathing)
            return
        }
        isAssessing = true
        var result = await companion.assess(text)
        isAssessing = false
        // Si la IA propone una causa que la persona no menciono, se descarta
        if !CalmGrounding.isMentioned(result.trigger, in: [text]) {
            result = CalmAssessment(intensity: result.intensity, trigger: "", technique: result.technique,
                                    message: result.message, source: result.source)
        }
        // En la respiracion el mensaje se muestra en pantalla; leerlo lo cortaria la voz de "Inhala"
        assessment = result
        start(result.technique)
    }

    // "Solo quiero respirar": empieza sin contar nada
    func skipIntake() {
        stopListening()
        start(.breathing)
    }

    private func start(_ chosen: CalmTechnique) {
        technique = chosen
        stepIndex = 0
        if chosen == .breathing {
            beginBreathing()
        } else {
            startTalking()
        }
    }

    // MARK: Respiracion

    private func beginBreathing() {
        stage = .breathing
        breathingRun += 1
    }

    // Corre los ciclos de respiracion; al terminar pasa sola a la conversacion
    func runBreathing() async {
        guard stage == .breathing else { return }
        for current in 1...pattern.cycles {
            for next in BreathPhase.allCases {
                guard stage == .breathing, !Task.isCancelled else { return }
                cycle = current
                phase = next
                breathCount += 1
                haptics.play(next, seconds: pattern.seconds(of: next))
                speak(next.label)
                try? await sleep(pattern.duration(of: next))
            }
        }
        guard stage == .breathing, !Task.isCancelled else { return }
        startTalking()
    }

    func breatheAgain() {
        stopListening()
        beginBreathing()
    }

    // MARK: Conversacion

    func startTalking() {
        haptics.stop()
        stage = .talking
        if messages.isEmpty { coach(CalmScript.opening(for: technique, after: assessment)) }
    }

    // Envia lo que escribio o dicto la persona; las señales de riesgo se revisan antes de usar la IA
    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isReplying else { return }
        stopListening()
        draft = ""
        messages.append(CalmMessage(role: .user, text: text))

        let found = CalmSafety.concerns(in: text)
        if !found.isEmpty {
            concerns.formUnion(found)
            coach(CalmSafety.message(for: found))
            return
        }
        guard let step = currentStep else {
            coach(CalmScript.closing)
            return
        }
        let next = steps.indices.contains(stepIndex + 1) ? steps[stepIndex + 1] : nil
        isReplying = true
        let reply = await companion.reply(to: text, answered: step, next: next, technique: technique)
        isReplying = false
        stepIndex += 1
        coach(reply.text)
    }

    func toggleListening() async {
        if dictation.isListening {
            stopListening()
            return
        }
        speech.stop()
        dictationError = nil
        do {
            try await dictation.start(onText: { [weak self] text in
                self?.draft = text
            }, onError: { [weak self] message in
                self?.dictationError = message
            })
        } catch {
            dictationError = error.localizedDescription
        }
    }

    // MARK: Cierre

    func finish() {
        stopListening()
        speech.stop()
        haptics.stop()
        stage = .checkIn
    }

    // Guarda la calificacion y pide a la IA el plan para la proxima vez
    func saveCheckIn(_ rating: Int) async {
        let rating = min(max(rating, 1), 10)
        lastRating = rating
        stage = .done
        isPlanning = true
        let previousTriggers = history.compactMap(\.trigger).filter { !$0.isEmpty }
        let summary = CalmSessionSummary(intake: intake, assessment: assessment, technique: technique,
                                         answers: messages.filter { $0.role == .user }.map(\.text),
                                         rating: rating, previousTriggers: previousTriggers)
        let result = grounded(await companion.plan(for: summary), summary: summary)
        plan = result
        isPlanning = false
        let trigger = assessment?.trigger.isEmpty == false ? assessment?.trigger : nil
        let checkIn = CalmCheckIn(date: Date(), rating: rating, startIntensity: assessment?.intensity,
                                  trigger: trigger, technique: technique, plan: result)
        store.save(checkIn)
        history.append(checkIn)
    }

    // El plan solo muestra causas y patrones que salen de lo que la persona escribio
    private func grounded(_ plan: CalmPlan, summary: CalmSessionSummary) -> CalmPlan {
        let said = [summary.intake] + summary.answers
        let triggerOK = CalmGrounding.isMentioned(plan.trigger, in: said)
        let currentTrigger = triggerOK ? plan.trigger : (summary.assessment?.trigger ?? "")
        let repeats = summary.previousTriggers.contains { CalmGrounding.isMentioned($0, in: [currentTrigger]) }
        return CalmPlan(trigger: triggerOK ? plan.trigger : "No lo identificamos esta vez.",
                        helped: plan.helped, nextTime: plan.nextTime,
                        pattern: repeats ? plan.pattern : nil, fromAI: plan.fromAI)
    }

    // Calificaciones de sesiones anteriores a la de hoy, de la mas vieja a la mas nueva
    var previousRatings: [Int] {
        let saved = plan == nil ? history : Array(history.dropLast())
        return saved.suffix(5).map(\.rating)
    }

    func toggleVoice() {
        speech.isMuted.toggle()
    }

    // Se llama al cerrar la pantalla
    func stop() {
        stage = .done
        haptics.stop()
        stopListening()
        speech.stop()
    }

    // MARK: Ayudantes

    private func coach(_ text: String) {
        messages.append(CalmMessage(role: .coach, text: text))
        speak(text)
    }

    private func speak(_ text: String) {
        guard !dictation.isListening else { return }
        speech.speak(text)
    }

    private func stopListening() {
        if dictation.isListening { dictation.stop() }
    }
}
