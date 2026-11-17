import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct CalmReply: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case ai
        case script
    }

    let text: String
    let source: Source
}

@MainActor
protocol CalmCompanioning: AnyObject {
    // Carga el modelo antes de que la persona escriba, para que la primera respuesta sea rapida
    func prewarm()
    // Entiende lo que cuenta la persona y elige la tecnica que mejor le sirve
    func assess(_ text: String) async -> CalmAssessment
    // Responde a un paso y pide el siguiente; next es nil cuando ya se terminaron los pasos
    func reply(to text: String, answered step: CalmStep, next: CalmStep?, technique: CalmTechnique) async -> CalmReply
    // Escribe el plan para la proxima vez con lo que paso en la sesion
    func plan(for session: CalmSessionSummary) async -> CalmPlan
}

extension CalmCompanioning {
    func prewarm() {}
}

enum CalmScript {
    static let closing = "Lo hiciste muy bien. Respira profundo una vez más. Cuando quieras, toca Terminar y cuéntame cómo te sientes."

    // Primer mensaje de la conversacion; es fijo para que aparezca de inmediato
    static func opening(for technique: CalmTechnique, after assessment: CalmAssessment?) -> String {
        let intro: String
        if technique == .breathing {
            intro = "Muy bien, ya respiraste. Ahora vamos a llevar tu atención a lo que te rodea, sin prisa."
        } else {
            intro = assessment?.message ?? "Estoy aquí contigo. Vamos paso a paso, sin prisa."
        }
        // Si la IA escribio una primera pregunta con lo que conto la persona, se usa esa
        let question = assessment?.firstQuestion ?? technique.steps[0].request
        return "\(intro) \(question)"
    }
}

// Version sin IA: palabras clave para elegir la tecnica, respuestas con guion y plan con plantilla
@MainActor
final class ScriptedCalmCompanion: CalmCompanioning {
    private static let encouragements = ["Muy bien.", "Gracias, vas muy bien.", "Eso es.", "Perfecto, sigue así."]

    // Se revisan en este orden: primero el cuerpo, luego la desconexion, luego la preocupacion
    private static let keywords: [(CalmTechnique, [String])] = [
        (.breathing, ["no puedo respirar", "me falta el aire", "corazon", "taquicardia", "tiemblo", "temblor",
                      "me ahogo", "sudo", "panico", "ataque"]),
        (.grounding, ["irreal", "desconect", "mareo", "mareado", "como en un sueno", "no siento mi cuerpo",
                      "fuera de mi", "no se donde estoy"]),
        (.reframing, ["examen", "trabajo", "escuela", "dinero", "manana", "preocupa", "que tal si",
                      "no se que hacer", "miedo de", "pelea", "discut"]),
    ]

    func assess(_ text: String) async -> CalmAssessment {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
        let technique = Self.keywords.first { $0.1.contains(where: normalized.contains) }?.0 ?? .breathing
        return CalmAssessment(intensity: nil, trigger: "", technique: technique,
                              message: Self.message(for: technique), source: .rules)
    }

    static func message(for technique: CalmTechnique) -> String {
        switch technique {
        case .breathing: "Gracias por contarme. Tu cuerpo está muy activado, así que empecemos respirando juntos."
        case .grounding: "Gracias por contarme. Vamos a traer tu atención al lugar donde estás, paso a paso."
        case .reframing: "Gracias por contarme. Vamos a ordenar esa preocupación juntos, una pregunta a la vez."
        }
    }

    func reply(to text: String, answered step: CalmStep, next: CalmStep?, technique: CalmTechnique) async -> CalmReply {
        guard let next else { return CalmReply(text: CalmScript.closing, source: .script) }
        let index = technique.steps.firstIndex(of: step) ?? 0
        let encouragement = Self.encouragements[index % Self.encouragements.count]
        return CalmReply(text: "\(encouragement) \(next.request)", source: .script)
    }

    func plan(for session: CalmSessionSummary) async -> CalmPlan {
        let trigger = session.assessment?.trigger ?? ""
        let repeats = trigger.isEmpty ? 0 : session.previousTriggers.filter { $0.caseInsensitiveCompare(trigger) == .orderedSame }.count
        return CalmPlan(
            trigger: trigger.isEmpty ? "No lo identificamos esta vez." : trigger,
            helped: session.technique.title,
            nextTime: Self.tip(for: session.technique),
            pattern: repeats == 0 ? nil : "No es la primera vez: ya te había pasado con \(trigger)."
        )
    }

    static func tip(for technique: CalmTechnique) -> String {
        switch technique {
        case .breathing: "Cuando notes que tu corazón se acelera, empieza la respiración 4-4-6 antes de que suba más."
        case .grounding: "Si vuelves a sentirte desconectado, nombra en voz alta lo que ves a tu alrededor."
        case .reframing: "Escribe tu preocupación y separa lo que sí puedes controlar de lo que no."
        }
    }
}

// Usa la IA de Apple en el dispositivo si esta disponible y el guion si no o si falla
@MainActor
final class FallbackCalmCompanion: CalmCompanioning {
    private let script = ScriptedCalmCompanion()
    // Guarda un FoundationModelCalmCompanion; el tipo es generico porque solo existe en iOS 26
    private var model: CalmModelCompanioning?

    func prewarm() {
        availableModel()?.prewarm()
    }

    func assess(_ text: String) async -> CalmAssessment {
        if let assessment = await availableModel()?.assessIfPossible(text) { return assessment }
        return await script.assess(text)
    }

    func reply(to text: String, answered step: CalmStep, next: CalmStep?, technique: CalmTechnique) async -> CalmReply {
        if let reply = await availableModel()?.replyIfPossible(to: text, answered: step, next: next, technique: technique) {
            return reply
        }
        return await script.reply(to: text, answered: step, next: next, technique: technique)
    }

    func plan(for session: CalmSessionSummary) async -> CalmPlan {
        if let plan = await availableModel()?.planIfPossible(for: session) { return plan }
        return await script.plan(for: session)
    }

    private func availableModel() -> CalmModelCompanioning? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            if model == nil { model = FoundationModelCalmCompanion() }
            return model
        }
        #endif
        return nil
    }
}

// Revisa que un detonante salga de lo que la persona escribio, para no mostrar causas inventadas por la IA
enum CalmGrounding {
    private static let ignored: Set<String> = ["esta", "este", "esto", "para", "como", "algo", "mucho", "mucha",
                                               "pero", "porque", "cuando", "tengo", "siento", "estoy", "sesion",
                                               "identificamos", "vez"]

    // Raices de las palabras importantes: sin acentos, de 4 letras o mas, recortadas a 5 letras
    // para que "agitado" y "agitada" o "examen" y "examenes" coincidan
    static func roots(_ text: String) -> Set<String> {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
        let words = folded.components(separatedBy: CharacterSet.letters.inverted).filter { $0.count >= 4 && !ignored.contains($0) }
        return Set(words.map { String($0.prefix(5)) })
    }

    static func isMentioned(_ phrase: String, in texts: [String]) -> Bool {
        let phraseRoots = roots(phrase)
        guard !phraseRoots.isEmpty else { return false }
        return !phraseRoots.isDisjoint(with: roots(texts.joined(separator: " ")))
    }
}

// Revisa el texto libre de la IA antes de mostrarlo: si parece datos (llaves, nombres de campos) se descarta
enum CalmReplyCleaner {
    private static let dataMarkers = ["{", "}", "[", "]", "technique", "intensity", "trigger", "message", "\":"]

    static func clean(_ text: String) -> String? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Quita comillas alrededor y etiquetas como "Respuesta:" al inicio
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"«»“” "))
        for label in ["Respuesta:", "Acompañante:", "Asistente:"] where cleaned.hasPrefix(label) {
            cleaned = String(cleaned.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
        }
        let lowered = cleaned.lowercased()
        guard !cleaned.isEmpty, !dataMarkers.contains(where: lowered.contains) else { return nil }
        return cleaned
    }
}

// Version de la IA que regresa nil cuando falla, para que FallbackCalmCompanion use el guion
@MainActor
protocol CalmModelCompanioning: AnyObject {
    func prewarm()
    func assessIfPossible(_ text: String) async -> CalmAssessment?
    func replyIfPossible(to text: String, answered step: CalmStep, next: CalmStep?, technique: CalmTechnique) async -> CalmReply?
    func planIfPossible(for session: CalmSessionSummary) async -> CalmPlan?
}

#if canImport(FoundationModels)
// Lo que la IA entiende de la persona, con valores permitidos para que la app pueda usarlos
@available(iOS 26.0, *)
@Generable
struct CalmAssessmentDraft {
    @Guide(description: "Qué tan intensa parece la ansiedad, de 1 (leve) a 10 (crisis muy fuerte).", .range(1...10))
    var intensity: Int

    @Guide(description: "Qué la detonó, en pocas palabras y en minúsculas, solo si la persona lo dijo explícitamente. Si no lo dijo, deja vacío. Nunca inventes ni supongas una causa.")
    var trigger: String

    @Guide(description: "'respiracion' si hay síntomas físicos fuertes (corazón acelerado, falta de aire, temblor); 'anclaje' si se siente desconectada, irreal o mareada; 'reencuadre' si es una preocupación concreta y puede pensar con calma.",
           .anyOf(["respiracion", "anclaje", "reencuadre"]))
    var technique: String

    @Guide(description: "Una o dos oraciones cálidas en español: valida lo que siente con tus propias palabras, sin repetir lo que dijo, y di qué van a hacer juntos. Sin preguntas.")
    var message: String

    @Guide(description: "La primera pregunta del ejercicio, en español y en una oración, conectada con lo que contó la persona. Con 'reencuadre': pregúntale qué es lo que más le preocupa que pase, refiriéndote a su situación con tus palabras. Con 'respiracion' o 'anclaje': pídele que mire a su alrededor y te diga tres cosas que vea, ligándolo al lugar donde está si lo mencionó. No inventes detalles que no dijo.")
    var firstQuestion: String
}

@available(iOS 26.0, *)
@Generable
struct CalmPlanDraft {
    @Guide(description: "Qué detonó la ansiedad en esta sesión, en una frase corta, solo si la persona lo dijo. Si no lo dijo, escribe exactamente: No lo identificamos esta vez. Nunca inventes una causa.")
    var trigger: String

    @Guide(description: "Qué le ayudó en esta sesión, en una frase corta y concreta.")
    var helped: String

    @Guide(description: "Una recomendación concreta y amable para la próxima vez que le pase, en una o dos oraciones.")
    var nextTime: String

    @Guide(description: "Solo si el detonante de esta sesión es claramente el mismo que alguno de sesiones anteriores, describe el patrón en una oración. Si no, deja vacío.")
    var pattern: String
}

// Acompañante con el modelo de lenguaje de Apple; corre en el iPhone y no envia la conversacion a internet
@available(iOS 26.0, *)
@MainActor
final class FoundationModelCalmCompanion: CalmModelCompanioning {
    private static let instructions = """
        Eres el acompañante de calma de Enlace Vital, la app de la Cruz Roja Mexicana. La persona puede \
        estar teniendo un ataque de pánico o mucha ansiedad. Primero entiendes qué le pasa, después la \
        guías paso a paso con una técnica y al final le dejas un plan. Responde siempre en español, con \
        calidez y calma, en una o dos oraciones cortas, porque tus respuestas se leen en voz alta. Habla \
        como una persona tranquila que de verdad escucha, no como un cuestionario: tus preguntas se \
        conectan con lo que la persona ha contado (su situación, el lugar donde está, lo que siente). \
        No repitas su frase ni la resumas; puedes retomar un detalle con tus propias palabras para que \
        sepa que la escuchaste. Varía cómo empiezas cada mensaje. Haz una sola pregunta a la vez. No diagnostiques, no hables de medicamentos y \
        no des consejos médicos. No uses listas ni emojis.
        """

    // Cada tarea usa su propia sesion: si la conversacion compartiera sesion con las respuestas
    // estructuradas, el modelo copiaria ese formato ({technique: ...}) en sus mensajes
    private var conversation: LanguageModelSession?
    // Lo que conto la persona al inicio, en texto normal, para darle contexto a la conversacion
    private var context = ""

    func prewarm() {
        LanguageModelSession(instructions: Self.instructions).prewarm()
    }

    func assessIfPossible(_ text: String) async -> CalmAssessment? {
        context = "Al inicio la persona contó: «\(text)»."
        conversation = nil
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = "La persona cuenta qué le está pasando: «\(text)». Entiende cómo está y elige la técnica."
        guard let draft = await run("assessment", { try await session.respond(to: prompt, generating: CalmAssessmentDraft.self).content })
        else { return nil }
        let technique: CalmTechnique = switch draft.technique {
        case "anclaje": .grounding
        case "reencuadre": .reframing
        default: .breathing
        }
        let message = CalmReplyCleaner.clean(draft.message) ?? ""
        let firstQuestion = CalmReplyCleaner.clean(draft.firstQuestion).flatMap { $0.count <= 200 ? $0 : nil }
        if !draft.trigger.isEmpty { context += " Lo que la detonó: \(draft.trigger)." }
        if let firstQuestion { context += " Tu primera pregunta del ejercicio fue: «\(firstQuestion)»." }
        return CalmAssessment(intensity: min(max(draft.intensity, 1), 10),
                              trigger: draft.trigger.trimmingCharacters(in: .whitespacesAndNewlines),
                              technique: technique,
                              message: message.isEmpty ? ScriptedCalmCompanion.message(for: technique) : message,
                              source: .ai,
                              firstQuestion: firstQuestion)
    }

    func replyIfPossible(to text: String, answered step: CalmStep, next: CalmStep?, technique: CalmTechnique) async -> CalmReply? {
        let nextInstruction = next.map {
            """
            Primero reacciona en una frase corta a algo concreto de su respuesta. Si dice que sigue muy mal \
            o habla de otra cosa que le pesa, atiende eso primero. Después escribe tu propia pregunta con este \
            objetivo: \($0.goal). Que la pregunta se relacione con lo que ha contado hasta ahora y no sea \
            genérica. Termina con esa pregunta.
            """
        } ?? "Ya terminó el ejercicio: reconoce algo concreto de lo que compartió, invítala a respirar profundo una vez más y dile que toque Terminar cuando quiera."
        let prompt = "Técnica: \(technique.title). Objetivo de este paso: \(step.goal).\nLa persona respondió: «\(text)»\n\(nextInstruction)"
        let session = conversationSession()
        guard let answer = await run("reply", { try await session.respond(to: prompt).content }),
              let cleaned = CalmReplyCleaner.clean(answer)
        else { return nil }
        // Si la IA olvido hacer la siguiente pregunta, se agrega la fija para que el ejercicio no se trabe
        if let next, !cleaned.contains("?") {
            return CalmReply(text: "\(cleaned) \(next.request)", source: .ai)
        }
        return CalmReply(text: cleaned, source: .ai)
    }

    func planIfPossible(for summary: CalmSessionSummary) async -> CalmPlan? {
        let previous = summary.previousTriggers.isEmpty ? "ninguno" : summary.previousTriggers.joined(separator: "; ")
        let answers = summary.answers.isEmpty ? "ninguna" : summary.answers.map { "«\($0)»" }.joined(separator: ", ")
        let prompt = """
            Un ejercicio de calma terminó. Al inicio la persona contó: «\(summary.intake)». \
            Técnica usada: \(summary.technique.title). Sus respuestas durante el ejercicio: \(answers). \
            Al final calificó su ansiedad en \(summary.rating) de 10\(summary.assessment?.intensity.map { " (al inicio parecía \($0))" } ?? ""). \
            Detonantes de sesiones anteriores: \(previous). Escribe su plan para la próxima vez.
            """
        let session = LanguageModelSession(instructions: Self.instructions)
        guard let draft = await run("plan", { try await session.respond(to: prompt, generating: CalmPlanDraft.self).content }),
              let trigger = CalmReplyCleaner.clean(draft.trigger),
              let helped = CalmReplyCleaner.clean(draft.helped),
              let nextTime = CalmReplyCleaner.clean(draft.nextTime)
        else { return nil }
        let pattern = CalmReplyCleaner.clean(draft.pattern)
        return CalmPlan(trigger: trigger, helped: helped, nextTime: nextTime,
                        pattern: summary.previousTriggers.isEmpty ? nil : pattern, fromAI: true)
    }

    // La conversacion recuerda lo que se ha dicho en el ejercicio, solo con texto normal
    private func conversationSession() -> LanguageModelSession {
        if let conversation { return conversation }
        let session = LanguageModelSession(instructions: "\(Self.instructions) \(context)")
        conversation = session
        return session
    }

    // Registra el tiempo y los errores; por ejemplo, el filtro de seguridad de Apple puede rechazar temas de salud mental
    private func run<T>(_ name: String, _ work: () async throws -> T) async -> T? {
        let start = Date()
        do {
            let result = try await work()
            Log.ai.info("Calm \(name, privacy: .public) in \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s")
            return result
        } catch {
            Log.ai.error("Calm \(name, privacy: .public) failed: \(String(reflecting: error), privacy: .public)")
            return nil
        }
    }
}
#endif
