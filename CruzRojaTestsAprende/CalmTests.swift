import Foundation
import Testing
@testable import CruzRoja

// Acompañante de prueba: elige la tecnica indicada, responde un texto fijo y guarda lo que se le pidio
@MainActor
private final class FakeCompanion: CalmCompanioning {
    var assessment = CalmAssessment(intensity: 8, trigger: "examen de mañana", technique: .reframing,
                                    message: "Entiendo que el examen te tiene así.", source: .ai)
    private(set) var assessed: [String] = []
    private(set) var replies: [(text: String, step: CalmStep, next: CalmStep?, technique: CalmTechnique)] = []
    private(set) var summaries: [CalmSessionSummary] = []

    func assess(_ text: String) async -> CalmAssessment {
        assessed.append(text)
        return assessment
    }

    func reply(to text: String, answered step: CalmStep, next: CalmStep?, technique: CalmTechnique) async -> CalmReply {
        replies.append((text, step, next, technique))
        return CalmReply(text: "Respuesta de la IA", source: .ai)
    }

    func plan(for session: CalmSessionSummary) async -> CalmPlan {
        summaries.append(session)
        return CalmPlan(trigger: "El examen", helped: "Ordenar la preocupación", nextTime: "Estudia por bloques.",
                        pattern: nil, fromAI: true)
    }
}

@MainActor
struct CalmTests {
    private let companion = FakeCompanion()
    private let speech = SilentSpeech()
    private let dictation = SilentDictation()
    private let haptics = SilentBreathHaptics()
    private let store = InMemoryCalmHistory()

    // Respiracion corta y sin esperas reales para que las pruebas sean rapidas
    private func makeViewModel(cycles: Int = 2, store: InMemoryCalmHistory? = nil) -> CalmViewModel {
        CalmViewModel(pattern: BreathingPattern(cycles: cycles), companion: companion, speech: speech,
                      dictation: dictation, haptics: haptics, store: store ?? self.store, sleep: { _ in })
    }

    private func say(_ text: String, to viewModel: CalmViewModel) async {
        viewModel.draft = text
        await viewModel.send()
    }

    private func tell(_ text: String, to viewModel: CalmViewModel) async {
        viewModel.draft = text
        await viewModel.submitIntake()
    }

    // MARK: Inicio y eleccion de tecnica

    @Test("Lo que cuenta la persona se manda a la IA, que elige la tecnica")
    func intakeChoosesTechnique() async {
        let viewModel = makeViewModel()
        #expect(viewModel.stage == .intake)
        await tell("Mañana tengo examen y no puedo dejar de pensar", to: viewModel)
        #expect(companion.assessed == ["Mañana tengo examen y no puedo dejar de pensar"])
        #expect(viewModel.technique == .reframing && viewModel.stage == .talking)
        #expect(viewModel.messages.first?.text == "Entiendo que el examen te tiene así. ¿Qué es lo que más te preocupa que pase?")
    }

    @Test("Si la IA elige respirar, empieza la respiracion y luego el anclaje")
    func breathingTechniqueThenGrounding() async {
        companion.assessment = CalmAssessment(intensity: 9, trigger: "", technique: .breathing,
                                              message: "Tu cuerpo está muy activado.", source: .ai)
        let viewModel = makeViewModel(cycles: 2)
        await tell("siento el corazón muy rápido", to: viewModel)
        #expect(viewModel.stage == .breathing && viewModel.breathingRun == 1)

        await viewModel.runBreathing()
        #expect(haptics.played == [.inhale, .hold, .exhale, .inhale, .hold, .exhale])
        #expect(speech.spoken.prefix(6) == ["Inhala", "Sostén", "Exhala", "Inhala", "Sostén", "Exhala"])
        #expect(viewModel.stage == .talking)
        #expect(viewModel.messages.first?.text.hasSuffix(CalmTechnique.grounding.steps[0].request) == true)
    }

    @Test("Se puede empezar a respirar sin contar nada")
    func skipIntakeStartsBreathing() {
        let viewModel = makeViewModel()
        viewModel.skipIntake()
        #expect(viewModel.stage == .breathing && viewModel.technique == .breathing)
        #expect(companion.assessed.isEmpty && viewModel.assessment == nil)
    }

    @Test("Una señal de riesgo al inicio no se manda a la IA y empieza a respirar")
    func intakeSafetyGoesToBreathing() async {
        let viewModel = makeViewModel()
        await tell("me duele mucho el pecho", to: viewModel)
        #expect(companion.assessed.isEmpty)
        #expect(viewModel.concerns == [.medical])
        #expect(viewModel.stage == .breathing)
        #expect(viewModel.assessment?.message.contains("911") == true)
    }

    @Test("Las reglas eligen la tecnica por palabras clave cuando no hay IA")
    func scriptedAssessmentKeywords() async {
        let script = ScriptedCalmCompanion()
        #expect(await script.assess("Siento taquicardia y tiemblo").technique == .breathing)
        #expect(await script.assess("Todo se ve irreal, como en un sueño").technique == .grounding)
        #expect(await script.assess("Me preocupa el dinero de la renta").technique == .reframing)
        #expect(await script.assess("no sé").technique == .breathing)
        #expect(await script.assess("examen").source == .rules)
    }

    // MARK: Conversacion

    @Test("Cada respuesta avanza un paso de la tecnica hasta terminar")
    func stepsAdvanceUntilDone() async {
        let viewModel = makeViewModel()
        await tell("examen", to: viewModel)  // reencuadre: 3 pasos
        for answer in ["reprobar", "estudiar sí, la calificación no", "repasar una hora"] {
            await say(answer, to: viewModel)
        }
        let steps = CalmTechnique.reframing.steps
        #expect(companion.replies.map(\.step) == steps)
        #expect(companion.replies.map(\.next) == [steps[1], steps[2], nil])
        #expect(companion.replies.allSatisfy { $0.technique == .reframing })
        #expect(viewModel.hasFinishedSteps)
    }

    @Test("Un mensaje vacio no se envia")
    func emptyMessageIsIgnored() async {
        let viewModel = makeViewModel()
        await tell("examen", to: viewModel)
        await say("   ", to: viewModel)
        #expect(companion.replies.isEmpty && viewModel.messages.count == 1)
    }

    @Test("Dolor de pecho durante la conversacion muestra el 911 y no se manda a la IA")
    func chestPainShowsEmergency() async {
        let viewModel = makeViewModel()
        await tell("examen", to: viewModel)
        await say("Me duele el pecho y el brazo izquierdo", to: viewModel)
        #expect(viewModel.concerns == [.medical])
        #expect(companion.replies.isEmpty && viewModel.stepIndex == 0)
        #expect(viewModel.messages.last?.text.contains("911") == true)
    }

    @Test("Mencionar hacerse daño muestra la Linea de la Vida")
    func selfHarmShowsCrisisLine() async {
        let viewModel = makeViewModel()
        await tell("examen", to: viewModel)
        await say("Ya no quiero vivir", to: viewModel)
        #expect(viewModel.concerns == [.selfHarm])
        #expect(viewModel.messages.last?.text.contains(CalmSafety.crisisLineLabel) == true)
    }

    @Test("Las reglas de seguridad ignoran acentos y mayusculas y no marcan frases normales")
    func safetyRules() {
        #expect(CalmSafety.concerns(in: "SIENTO PRESIÓN EN EL PECHO") == [.medical])
        #expect(CalmSafety.concerns(in: "me duele muchísimo el pecho") == [.medical])
        #expect(CalmSafety.concerns(in: "siento el pecho apretado") == [.medical])
        #expect(CalmSafety.concerns(in: "me duele la cabeza") == [])
        #expect(CalmSafety.concerns(in: "pense en suicidarme") == [.selfHarm])
        #expect(CalmSafety.concerns(in: "veo una lámpara y mi perro") == [])
    }

    @Test("El guion responde cada paso y cierra al final")
    func scriptedReplies() async {
        let script = ScriptedCalmCompanion()
        let steps = CalmTechnique.grounding.steps
        let first = await script.reply(to: "mesa", answered: steps[0], next: steps[1], technique: .grounding)
        #expect(first.text.hasSuffix(steps[1].request) && first.source == .script)
        #expect(steps.count == 3)
        let last = await script.reply(to: "fríos", answered: steps[2], next: nil, technique: .grounding)
        #expect(last.text == CalmScript.closing)
    }

    // MARK: Cierre y plan

    @Test("Al calificar se pide el plan con lo que paso y se guarda la sesion")
    func checkInCreatesPlanAndSaves() async throws {
        let history = InMemoryCalmHistory([CalmCheckIn(date: .now, rating: 7, trigger: "examen de física")])
        let viewModel = makeViewModel(store: history)
        await tell("examen", to: viewModel)
        await say("reprobar", to: viewModel)
        viewModel.finish()
        #expect(viewModel.stage == .checkIn)

        await viewModel.saveCheckIn(4)
        #expect(viewModel.stage == .done && viewModel.lastRating == 4)
        #expect(viewModel.plan?.nextTime == "Estudia por bloques.")
        let summary = try #require(companion.summaries.first)
        #expect(summary.intake == "examen" && summary.answers == ["reprobar"] && summary.rating == 4)
        #expect(summary.previousTriggers == ["examen de física"])

        let saved = try #require(history.checkIns.last)
        #expect(saved.rating == 4 && saved.startIntensity == 8 && saved.trigger == "examen de mañana")
        #expect(saved.technique == .reframing && saved.plan == viewModel.plan)
        #expect(viewModel.previousRatings == [7])
    }

    @Test("Si la IA inventa una causa que la persona no dijo, no se muestra")
    func inventedTriggerIsDropped() async throws {
        // El acompañante falso siempre dice que fue un examen
        let history = InMemoryCalmHistory([CalmCheckIn(date: .now, rating: 7, trigger: "examen de física")])
        let viewModel = makeViewModel(store: history)
        await tell("me siento muy agitado", to: viewModel)
        #expect(viewModel.assessment?.trigger == "")
        await say("veo la tele", to: viewModel)
        viewModel.finish()
        await viewModel.saveCheckIn(5)
        #expect(viewModel.plan?.trigger == "No lo identificamos esta vez.")
        #expect(viewModel.plan?.pattern == nil)
        #expect(history.checkIns.last?.trigger == nil)
    }

    @Test("Una causa se reconoce aunque cambie la forma de la palabra")
    func groundingMatchesWordForms() {
        #expect(CalmGrounding.isMentioned("exámenes finales", in: ["mañana tengo examen"]))
        #expect(CalmGrounding.isMentioned("sentirse agitada", in: ["me siento agitado"]))
        #expect(!CalmGrounding.isMentioned("examen de mañana", in: ["me siento agitado"]))
        #expect(!CalmGrounding.isMentioned("", in: ["lo que sea"]))
    }

    @Test("Sin IA, el plan usa la tecnica y detecta si el detonante se repite")
    func scriptedPlanFindsPattern() async {
        let script = ScriptedCalmCompanion()
        let assessment = CalmAssessment(intensity: nil, trigger: "examen", technique: .reframing, message: "", source: .rules)
        let summary = CalmSessionSummary(intake: "examen", assessment: assessment, technique: .reframing, answers: [],
                                         rating: 5, previousTriggers: ["Examen", "pelea"])
        let plan = await script.plan(for: summary)
        #expect(plan.helped == CalmTechnique.reframing.title)
        #expect(plan.nextTime == ScriptedCalmCompanion.tip(for: .reframing))
        #expect(plan.pattern?.contains("examen") == true)

        let first = await script.plan(for: CalmSessionSummary(intake: "", assessment: nil, technique: .breathing,
                                                              answers: [], rating: 5, previousTriggers: []))
        #expect(first.trigger == "No lo identificamos esta vez." && first.pattern == nil)
    }

    @Test("Los registros viejos sin plan se siguen leyendo")
    func oldCheckInsDecode() throws {
        let json = #"[{"date":0,"rating":6}]"#
        let decoded = try JSONDecoder().decode([CalmCheckIn].self, from: Data(json.utf8))
        #expect(decoded.first?.rating == 6 && decoded.first?.plan == nil)
    }

    @Test("Las respuestas de la IA que parecen datos se descartan antes de mostrarse")
    func cleanerRejectsDataLikeText() {
        #expect(CalmReplyCleaner.clean(#"{technique: "respiracionn", intensity: 8}"#) == nil)
        #expect(CalmReplyCleaner.clean(#"intensity: 7, message: "hola""#) == nil)
        #expect(CalmReplyCleaner.clean("   ") == nil)
        #expect(CalmReplyCleaner.clean("Respuesta: Qué bien que notaste la ventana.") == "Qué bien que notaste la ventana.")
        #expect(CalmReplyCleaner.clean("«Vas muy bien. Ahora dime 4 cosas que puedas tocar.»")
                == "Vas muy bien. Ahora dime 4 cosas que puedas tocar.")
    }

    // MARK: Otros

    @Test("Silenciar la voz evita que se lean las respuestas")
    func muteStopsSpeech() async {
        let viewModel = makeViewModel(cycles: 1)
        viewModel.toggleVoice()
        #expect(!viewModel.isVoiceOn)
        viewModel.skipIntake()
        await viewModel.runBreathing()
        #expect(speech.spoken.isEmpty)
    }

    @Test("Siri deja pendiente abrir Calma una sola vez")
    func launcherIsConsumedOnce() {
        let launcher = CalmLauncher()
        #expect(!launcher.consume())
        launcher.request()
        #expect(launcher.consume())
        #expect(!launcher.consume())
    }
}
