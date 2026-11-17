import Foundation

// Datos que se reconocieron en lo que dictó la persona; vacío o nil = no lo dijo
struct ProfileFields: Equatable, Sendable {
    var age: Int?
    var dateOfBirth: Date?
    var bloodType: BloodType?
    var noKnownAllergies = false
    var allergies: [String] = []
    var conditions: [String] = []
    var medications: [String] = []
    var contacts: [EmergencyContact] = []
    // Quién llenó los datos: la IA del iPhone o las palabras clave (con el motivo)
    var source: ExtractionSource = .rules(reason: nil)

    // True cuando no se reconoció ningún dato
    var isEmpty: Bool {
        age == nil && dateOfBirth == nil && bloodType == nil && !noKnownAllergies && allergies.isEmpty
            && conditions.isEmpty && medications.isEmpty && contacts.isEmpty
    }

    // Fecha real y no futura; nil si el día no existe (ej. 31 de febrero)
    static func birthDate(day: Int, month: Int, year: Int) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        guard (1...12).contains(month), (1...31).contains(day), year >= 1900,
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.day, from: date) == day, date <= Date()
        else { return nil }
        return date
    }

    // "1958-03-14", el formato que devuelve la IA
    static func birthDate(iso text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return birthDate(day: parts[2], month: parts[1], year: parts[0])
    }
}

// Saca los datos del perfil médico de un texto dictado
@MainActor
protocol ProfileExtracting {
    func extract(_ text: String) async throws -> ProfileFields
}

// Respaldo sin IA: reconoce frases comunes como "soy alérgico a…", "tomo…" o "soy diabético"
struct RuleBasedProfileExtractor: Sendable {
    func fields(from text: String) -> ProfileFields {
        let lower = text.lowercased()
        var fields = ProfileFields()

        if let age = Self.firstMatch(#"(\d{1,3})\s*años"#, in: lower).flatMap({ Int($0[1]) }), age <= 120 {
            fields.age = age
        }
        fields.dateOfBirth = Self.birthDate(in: lower)
        fields.bloodType = Self.bloodType(in: lower)

        fields.noKnownAllergies = Self.firstMatch(
            #"no (?:tengo|tiene) (?:ninguna )?alergia|no (?:soy|es) al[eé]rgic|sin alergias"#, in: lower) != nil
        if !fields.noKnownAllergies {
            fields.allergies = Self.items(after: #"(?:al[eé]rgic[oa]s?|alergias?)\s+(?:a|al)?\s*([^.;]+)"#, in: lower)
        }
        fields.medications = Self.items(after: #"(?:^|\s)(?:tomo|toma|uso|usa|me inyecto|se inyecta)\s+([^.;]+)"#, in: lower)
        fields.conditions = Self.knownConditions.compactMap { keys, name in
            keys.contains { lower.contains($0) } ? name : nil
        }
        fields.contacts = Self.contacts(in: text)
        return fields
    }

    // Padecimientos comunes y las palabras con que se suelen mencionar
    private static let knownConditions: [(keys: [String], name: String)] = [
        (["diab"], "Diabetes"),
        (["hipertens", "presión alta", "presion alta"], "Hipertensión"),
        (["asma", "asmátic", "asmatic"], "Asma"),
        (["epilep"], "Epilepsia"),
        (["cáncer", "cancer"], "Cáncer"),
        (["del corazón", "del corazon", "cardiac", "cardiopat", "infarto"], "Enfermedad del corazón"),
        (["renal", "riñón", "riñones"], "Enfermedad renal"),
        (["tiroides"], "Tiroides"),
        (["artritis"], "Artritis"),
        (["epoc"], "EPOC"),
    ]

    private static let months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
                                 "septiembre", "octubre", "noviembre", "diciembre"]

    // "nací el 14 de marzo de 1958", "mi fecha de nacimiento es 14/03/1958"
    private static func birthDate(in text: String) -> Date? {
        let monthNames = (months + ["setiembre"]).joined(separator: "|")
        if let match = firstMatch(#"nac[ií]\w*[^\d]{0,30}?(\d{1,2})\s+de\s+("# + monthNames + #")\s+(?:de|del)\s+(\d{4})"#, in: text) {
            let month = (months.firstIndex(of: match[2] == "setiembre" ? "septiembre" : match[2]) ?? -1) + 1
            return ProfileFields.birthDate(day: Int(match[1]) ?? 0, month: month, year: Int(match[3]) ?? 0)
        }
        if let match = firstMatch(#"nac[ií]\w*[^\d]{0,30}?(\d{1,2})[/-](\d{1,2})[/-](\d{4})"#, in: text) {
            return ProfileFields.birthDate(day: Int(match[1]) ?? 0, month: Int(match[2]) ?? 0, year: Int(match[3]) ?? 0)
        }
        return nil
    }

    // "sangre O positivo", "tipo A negativo", "sangre es AB+"
    private static func bloodType(in text: String) -> BloodType? {
        guard let match = firstMatch(#"(?:sangre|tipo)\s+(?:es\s+|de\s+)?(ab|a|b|o|0|cero)\s*(positivo|negativo|\+|-)"#, in: text)
        else { return nil }
        let group = ["0": "O", "cero": "O"][match[1]] ?? match[1].uppercased()
        let sign = (match[2] == "positivo" || match[2] == "+") ? "+" : "-"
        return BloodType(rawValue: group + sign)
    }

    // "mi hija Ana, su teléfono es 81 1234 5678"
    private static func contacts(in text: String) -> [EmergencyContact] {
        let pattern = #"mi\s+(hija|hijo|esposa|esposo|mamá|mama|madre|papá|papa|padre|hermana|hermano|nieta|nieto|tía|tia|tío|tio|pareja)\s+([a-záéíóúñ]+)?[^\d]{0,40}?((?:\d[\s-]?){9}\d)"#
        let notNames: Set<String> = ["su", "es", "al", "que", "con", "y", "el", "la", "número", "numero", "teléfono", "telefono", "tiene", "se", "del"]
        return allMatches(pattern, in: text).map { match in
            let relationship = capitalized(match[1])
            let name = notNames.contains(match[2].lowercased()) ? "" : capitalized(match[2])
            return EmergencyContact(name: name.isEmpty ? relationship : name,
                                    relationship: relationship,
                                    phone: MedicalProfile.digitsOnly(match[3]))
        }
    }

    // Toma lo que sigue a una frase ("alérgico a …") hasta que empieza otra idea, y lo separa por comas o "y"
    private static func items(after pattern: String, in text: String) -> [String] {
        allMatches(pattern, in: text).flatMap { split(cutAtNextIdea($0[1])) }
    }

    private static let nextIdea = [" tomo ", " soy ", " tengo ", " uso ", " mi ", " me ", " padezco ", " pero "]
    private static let articles = ["a la ", "a las ", "a los ", "al ", "a ", "la ", "las ", "los ", "el ", "unas ", "unos ", "una ", "un "]

    private static func cutAtNextIdea(_ value: String) -> String {
        let padded = " " + value + " "
        let end = nextIdea.compactMap { padded.range(of: $0)?.lowerBound }.min() ?? padded.endIndex
        return String(padded[..<end]).trimmingCharacters(in: .whitespaces)
    }

    private static func split(_ value: String) -> [String] {
        let parts = (" " + value + " ")
            .replacingOccurrences(of: " y ", with: ",")
            .replacingOccurrences(of: " e ", with: ",")
            .components(separatedBy: ",")
        return parts.compactMap { part in
            var text = part.trimmingCharacters(in: .whitespaces)
            if let article = articles.first(where: { text.hasPrefix($0) }) {
                text = String(text.dropFirst(article.count))
            }
            text = text.trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : capitalized(text)
        }
    }

    // Solo la primera letra en mayúscula: "látex" → "Látex"
    private static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        allMatches(pattern, in: text).first
    }

    // Cada coincidencia como lista de grupos; un grupo que no participó es ""
    private static func allMatches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { i in
                let range = match.range(at: i)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }
}

// La conformidad va en una extensión para que el struct no quede atado al hilo principal
extension RuleBasedProfileExtractor: ProfileExtracting {
    func extract(_ text: String) async throws -> ProfileFields {
        fields(from: text)
    }
}
