import Foundation

// Fields detected in the free text; nil means "not mentioned"
struct ExtractedFields: Equatable, Sendable {
    var reportingFor: ReportingFor?
    var patientName: String?
    var reason: String?
    var injuredCount: Int?
    var injury: String?
    var place: String?
    var mentalState: String?
    var breathing: String?
    var skin: String?
}

extension EmergencyReport {
    // Only overwrites the fields that were detected
    func merging(_ fields: ExtractedFields) -> EmergencyReport {
        var copy = self
        copy.reportingFor = fields.reportingFor ?? reportingFor
        copy.patientName = fields.patientName ?? patientName
        copy.reason = fields.reason ?? reason
        copy.injuredCount = fields.injuredCount ?? injuredCount
        copy.injury = fields.injury ?? injury
        copy.place = fields.place ?? place
        copy.mentalState = fields.mentalState ?? mentalState
        copy.breathing = fields.breathing ?? breathing
        copy.skin = fields.skin ?? skin
        return copy
    }
}

// Turns the user's description into report fields; an on-device LLM can replace it later
protocol ReportExtracting: Sendable {
    func extract(_ text: String) -> ExtractedFields
}

// Keyword rules in Spanish, matched without accents; same rules as the Android app
struct RuleBasedReportExtractor: ReportExtracting {
    func extract(_ text: String) -> ExtractedFields {
        let t = Self.normalize(text)
        let relative = Self.relatives.first { t.contains("mi \($0)") }
        return ExtractedFields(
            reportingFor: relative.map { _ in .familyMember },
            patientName: relative.map { $0.prefix(1).uppercased() + $0.dropFirst() },
            reason: Self.firstMatch(t, Self.reasons),
            injuredCount: Self.injuredCount(t),
            injury: Self.injury(t),
            place: Self.firstMatch(t, Self.places),
            mentalState: Self.firstMatch(t, Self.mentalStates),
            breathing: Self.firstMatch(t, Self.breathing),
            skin: Self.firstMatch(t, Self.skin)
        )
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX")).lowercased()
    }

    private static func firstMatch(_ text: String, _ rules: [([String], String)]) -> String? {
        rules.first { keywords, _ in keywords.contains { text.contains($0) } }?.1
    }

    private static func injuredCount(_ text: String) -> Int? {
        let nouns = "(personas|lesionados|heridos|heridas)"
        if let match = text.range(of: "\\d+ \(nouns)", options: .regularExpression),
           let number = Int(text[match].prefix { $0.isNumber }) {
            return number
        }
        for (word, value) in numberWords where text.range(of: "\\b\(word) \(nouns)", options: .regularExpression) != nil {
            return value
        }
        return nil
    }

    private static func injury(_ text: String) -> String? {
        let part = bodyParts.first { text.contains($0.0) }?.1
        if text.contains("fractur") || text.contains("hueso") { return "Posible fractura" + (part.map { " de \($0)" } ?? "") }
        if text.contains("golpe"), let part { return "Golpe en \(part)" }
        if text.contains("sangr") || text.contains("cort") { return "Sangrado" + (part.map { " en \($0)" } ?? "") }
        if text.contains("quem") { return "Quemadura" + (part.map { " en \($0)" } ?? "") }
        return part.map { "Lesión en \($0)" }
    }

    private static let relatives = ["abuela", "abuelo", "mama", "papa", "hija", "hijo", "esposa", "esposo", "hermana", "hermano", "tia", "tio"]

    private static let reasons: [([String], String)] = [
        (["infarto", "dolor en el pecho", "paro card"], "Posible infarto"),
        (["convuls", "epilep"], "Convulsión"),
        (["atragant", "ahog"], "Atragantamiento"),
        (["choque", "choco", "chocaron", "atropell", "accidente de auto", "accidente vial"], "Accidente vial"),
        (["quem"], "Quemadura"),
        (["desmay", "perdio el conocimiento"], "Desmayo"),
        (["cayo", "caida", "me cai", "resbal", "tropez"], "Caída"),
        (["sangr", "hemorrag", "cort"], "Hemorragia"),
        (["fractur"], "Posible fractura"),
    ]

    private static let places: [([String], String)] = [
        (["casa", "departamento", "hogar", "cuarto", "cocina", "bano", "escalera"], "Casa habitación"),
        (["calle", "avenida", "carretera", "banqueta", "cruce"], "Vía pública"),
        (["trabajo", "oficina", "fabrica"], "Trabajo"),
        (["escuela", "salon", "universidad"], "Escuela"),
        (["parque", "plaza"], "Parque"),
    ]

    private static let mentalStates: [([String], String)] = [
        (["inconsciente", "no responde", "desmay", "perdio el conocimiento"], "Inconsciente"),
        (["confundid", "desorientad", "maread", "no sabe donde"], "Confundido"),
        (["consciente", "alerta", "habla bien", "esta despiert"], "Alerta"),
    ]

    private static let breathing: [([String], String)] = [
        (["no respira"], "No respira"),
        (["le cuesta respirar", "dificultad para respirar", "respira mal", "se ahoga", "ahog"], "Con dificultad"),
        (["respira bien", "respira normal", "si respira", "respira"], "Normal"),
    ]

    private static let skin: [([String], String)] = [
        (["palid"], "Pálida"),
        (["azul", "morad"], "Azulada"),
    ]

    private static let bodyParts = [
        ("cabeza", "la cabeza"), ("pierna", "la pierna"), ("brazo", "el brazo"), ("mano", "la mano"),
        ("pecho", "el pecho"), ("espalda", "la espalda"), ("cadera", "la cadera"), ("tobillo", "el tobillo"),
    ]

    private static let numberWords = [("una", 1), ("un", 1), ("dos", 2), ("tres", 3), ("cuatro", 4), ("cinco", 5)]
}
