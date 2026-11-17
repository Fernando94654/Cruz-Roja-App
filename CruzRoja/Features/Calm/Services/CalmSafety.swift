import Foundation

// Señales de que no es solo un ataque de panico; se revisan con reglas fijas antes de usar la IA
enum SafetyConcern: Hashable, Sendable {
    // Sintomas que pueden ser un infarto u otra emergencia medica: llamar al 911
    case medical
    // La persona menciona hacerse daño: Linea de la Vida
    case selfHarm
}

enum CalmSafety {
    static let emergencyNumber = "911"
    // Linea de la Vida, gratuita y las 24 horas en Mexico
    static let crisisLineNumber = "8009112000"
    static let crisisLineLabel = "800 911 2000"

    // Las frases se comparan sin acentos ni mayusculas
    private static let medicalPhrases = [
        "dolor en el pecho", "dolor de pecho", "me duele el pecho", "presion en el pecho", "opresion en el pecho",
        "brazo izquierdo", "mandibula", "me desmaye", "me voy a desmayar", "desmayo", "no puedo respirar",
        "me ahogo", "labios morados", "convulsion",
    ]

    private static let selfHarmPhrases = [
        "suicid", "matarme", "quitarme la vida", "hacerme dano", "no quiero vivir", "quiero morir",
        "cortarme", "lastimarme", "acabar con todo", "acabar con mi vida",
    ]

    static func concerns(in text: String) -> Set<SafetyConcern> {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
        var found = Set<SafetyConcern>()
        if medicalPhrases.contains(where: normalized.contains) || hasChestPain(normalized) { found.insert(.medical) }
        if selfHarmPhrases.contains(where: normalized.contains) { found.insert(.selfHarm) }
        return found
    }

    // "Me duele mucho el pecho", "siento el pecho apretado": pecho junto con dolor o presion, en cualquier orden
    private static let painWords = ["duele", "dolor", "presion", "opresion", "aprieta", "apretado", "punzada"]

    private static func hasChestPain(_ normalized: String) -> Bool {
        normalized.contains("pecho") && painWords.contains(where: normalized.contains)
    }

    // Respuesta fija del acompañante cuando aparece una señal; no se deja a la IA
    static func message(for concerns: Set<SafetyConcern>) -> String {
        var parts: [String] = []
        if concerns.contains(.selfHarm) {
            parts.append("Gracias por decírmelo. No estás solo: habla ahora con la Línea de la Vida al \(crisisLineLabel), es gratis y atienden las 24 horas.")
        }
        if concerns.contains(.medical) {
            parts.append("Lo que describes puede ser una emergencia médica. Si el dolor es fuerte, se extiende al brazo o la mandíbula, o no se quita en unos minutos, llama al 911 ahora.")
        }
        return parts.joined(separator: " ")
    }
}
