import Foundation

// Etapas: contar que pasa, hacer la tecnica elegida, calificar como se siente y ver el plan
enum CalmStage: Equatable, Sendable {
    case intake
    case breathing
    case talking
    case checkIn
    case done
}

// Fases de una respiracion guiada
enum BreathPhase: CaseIterable, Sendable {
    case inhale
    case hold
    case exhale

    var label: String {
        switch self {
        case .inhale: "Inhala"
        case .hold: "Sostén"
        case .exhale: "Exhala"
        }
    }
}

// Respiracion 4-4-6: exhalar mas largo que inhalar ayuda a bajar el ritmo del corazon
struct BreathingPattern: Equatable, Sendable {
    var inhale: Duration = .seconds(4)
    var hold: Duration = .seconds(4)
    var exhale: Duration = .seconds(6)
    var cycles = 4

    static let standard = BreathingPattern()

    func duration(of phase: BreathPhase) -> Duration {
        switch phase {
        case .inhale: inhale
        case .hold: hold
        case .exhale: exhale
        }
    }

    func seconds(of phase: BreathPhase) -> Double {
        let components = duration(of: phase).components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

// Un paso de la conversacion: para que sirve y la pregunta fija que se usa si no hay IA
struct CalmStep: Equatable, Sendable {
    // Lo que se busca con el paso; la IA escribe su propia pregunta con este objetivo
    let goal: String
    let request: String
}

// Tecnicas que puede elegir la IA segun lo que cuenta la persona
enum CalmTechnique: String, CaseIterable, Codable, Sendable {
    // Sintomas fisicos fuertes: corazon acelerado, falta de aire, temblor
    case breathing
    // Sensacion de desconexion o irrealidad: anclaje con los sentidos
    case grounding
    // Preocupacion concreta: ordenar lo que si se puede controlar
    case reframing

    var title: String {
        switch self {
        case .breathing: "Respiración 4-4-6"
        case .grounding: "Anclaje con los sentidos"
        case .reframing: "Ordenar la preocupación"
        }
    }

    // Pasos de la conversacion; despues de respirar se continua con el anclaje
    var steps: [CalmStep] {
        switch self {
        case .breathing, .grounding:
            // Version corta del anclaje: lo que ves, lo que escuchas y tu cuerpo en el lugar
            [
                CalmStep(goal: "que mire a su alrededor y nombre tres cosas que ve",
                         request: "Mira a tu alrededor y dime 3 cosas que veas."),
                CalmStep(goal: "que ponga atención a los sonidos que hay donde está y diga cuáles escucha",
                         request: "Ahora pon atención a los sonidos. ¿Qué escuchas?"),
                CalmStep(goal: "que sienta su cuerpo apoyado (los pies en el suelo o donde está sentada) y diga cómo lo siente",
                         request: "Siente tus pies apoyados en el suelo. ¿Cómo los sientes?"),
            ]
        case .reframing:
            [
                CalmStep(goal: "que diga qué es lo que más le preocupa que pase con su situación",
                         request: "¿Qué es lo que más te preocupa que pase?"),
                CalmStep(goal: "que separe, de eso que le preocupa, lo que sí está en sus manos de lo que no depende de ella",
                         request: "De eso, ¿qué sí está en tus manos y qué no depende de ti?"),
                CalmStep(goal: "que piense un paso pequeño y concreto que podría dar hoy sobre lo que sí está en sus manos",
                         request: "¿Cuál es un paso pequeño que podrías dar hoy?"),
            ]
        }
    }
}

// Lo que entendio la IA (o las reglas) de lo que conto la persona
struct CalmAssessment: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case ai
        case rules
    }

    // Intensidad estimada de 1 a 10; nil si no se pudo estimar
    let intensity: Int?
    // Lo que detono la ansiedad en pocas palabras; vacio si no se sabe
    let trigger: String
    let technique: CalmTechnique
    // Mensaje calido que explica que van a hacer juntos
    let message: String
    let source: Source
    // Primera pregunta del ejercicio escrita por la IA con lo que conto la persona; nil usa la fija
    var firstQuestion: String? = nil
}

// Plan que se muestra al terminar y se guarda para la proxima vez
struct CalmPlan: Codable, Equatable, Sendable {
    let trigger: String
    let helped: String
    let nextTime: String
    // Patron entre sesiones, por ejemplo "suele pasarte antes de examenes"; nil si no hay
    let pattern: String?
    var fromAI = false
}

// Datos de la sesion que se usan para escribir el plan
struct CalmSessionSummary: Sendable {
    let intake: String
    let assessment: CalmAssessment?
    let technique: CalmTechnique
    let answers: [String]
    let rating: Int
    // Detonantes de sesiones anteriores, para encontrar patrones
    let previousTriggers: [String]
}

// Mensaje de la conversacion; el acompañante es la app y el usuario es la persona
struct CalmMessage: Identifiable, Equatable, Sendable {
    enum Role: Sendable {
        case coach
        case user
    }

    let id = UUID()
    let role: Role
    let text: String
}

// Registro de cada sesion guardado en el telefono
struct CalmCheckIn: Codable, Equatable, Sendable {
    let date: Date
    // 1 = tranquilo, 10 = ansiedad muy intensa
    let rating: Int
    // Los campos siguientes son opcionales para leer registros de versiones anteriores
    var startIntensity: Int?
    var trigger: String?
    var technique: CalmTechnique?
    var plan: CalmPlan?
}
