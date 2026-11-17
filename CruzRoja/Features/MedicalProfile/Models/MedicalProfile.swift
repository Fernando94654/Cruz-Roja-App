import Foundation

enum BloodType: String, Codable, CaseIterable, Identifiable, Sendable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case oPositive = "O+"
    case oNegative = "O-"
    case unknown

    var id: String { rawValue }

    var label: String {
        self == .unknown ? "No lo sé" : rawValue
    }
}

struct EmergencyContact: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var relationship: String
    var phone: String

    enum CodingKeys: String, CodingKey {
        case name, relationship, phone
    }

    var formattedPhone: String {
        MedicalProfile.formatPhone(phone)
    }
}

// Información médica del usuario
struct MedicalProfile: Equatable, Sendable {
    var userID: UUID?
    var fullName: String = ""
    var dateOfBirth: Date?
    var bloodType: BloodType = .unknown
    var allergies: [String] = []
    var conditions: [String] = []
    var medications: [String] = []
    var contacts: [EmergencyContact] = []
    var updatedAt: Date?

    static let maxContacts = 5

    // Lo que se guarda cuando la persona confirma que no tiene nada en esa lista.
    // Así el paramédico distingue "no tiene" de "no lo llenó".
    static let noAllergies = "Sin alergias conocidas"
    static let noConditions = "Sin padecimientos conocidos"
    static let noMedications = "Sin medicamentos"
}

extension MedicalProfile {
    static func digitsOnly(_ text: String) -> String {
        String(text.filter { $0.isASCII && $0.isNumber })
    }

    // El teléfono debe tener 10 dígitos
    static func isValidPhone(_ text: String) -> Bool {
        digitsOnly(text).count == 10
    }

    static func formatPhone(_ text: String) -> String {
        let d = Array(digitsOnly(text))
        guard d.count == 10 else { return text }
        return "\(String(d[0..<2])) \(String(d[2..<6])) \(String(d[6..<10]))"
    }

    var validationErrors: [String] {
        var errors: [String] = []
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Escribe el nombre de la persona.")
        }
        if let dateOfBirth, dateOfBirth > Date() {
            errors.append("La fecha de nacimiento no puede ser futura.")
        }
        if contacts.count > Self.maxContacts {
            errors.append("Puedes registrar hasta \(Self.maxContacts) contactos.")
        }
        for (i, contact) in contacts.enumerated() {
            let label = "Contacto \(i + 1)"
            if contact.name.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append("\(label): escribe su nombre.")
            }
            if contact.relationship.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append("\(label): escribe el parentesco.")
            }
            if !Self.isValidPhone(contact.phone) {
                errors.append("\(label): el teléfono debe tener 10 dígitos.")
            }
        }
        return errors
    }

    var isValid: Bool { validationErrors.isEmpty }

    func cleaned() -> MedicalProfile {
        var copy = self
        copy.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.allergies = Self.cleanList(allergies, none: Self.noAllergies)
        copy.conditions = Self.cleanList(conditions, none: Self.noConditions)
        copy.medications = Self.cleanList(medications, none: Self.noMedications)
        copy.contacts = contacts.map { contact in
            var c = contact
            c.name = c.name.trimmingCharacters(in: .whitespaces)
            c.relationship = c.relationship.trimmingCharacters(in: .whitespaces)
            c.phone = Self.digitsOnly(c.phone)
            return c
        }
        return copy
    }

    // Quita vacíos y repetidos; si hay datos reales, quita también el "Sin…"
    static func cleanList(_ list: [String], none: String? = nil) -> [String] {
        var seen = Set<String>()
        let items: [String] = list.compactMap { item in
            let text = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, seen.insert(text.lowercased()).inserted else { return nil }
            return text
        }
        guard let none, items.count > 1 else { return items }
        return items.filter { $0 != none }
    }

    func age(on day: Date = Date()) -> Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: day).year
    }
}

extension MedicalProfile {
    // Texto que va dentro del código QR
    func qrText(includeContacts: Bool) -> String {
        var lines = ["CRUZ ROJA · PERFIL MÉDICO"]
        lines.append("Nombre: \(fullName)")
        if let age = age() {
            lines.append("Edad: \(age) años")
        }
        lines.append("Sangre: \(bloodType.label)")
        lines.append("Alergias: \(Self.text(for: allergies))")
        lines.append("Padecimientos: \(Self.text(for: conditions))")
        lines.append("Medicamentos: \(Self.text(for: medications))")
        if includeContacts {
            for c in contacts {
                lines.append("Contacto: \(c.name) (\(c.relationship)) \(c.formattedPhone)")
            }
        }
        return lines.joined(separator: "\n")
    }

    var reportSummary: String {
        [
            "Sangre \(bloodType.label)",
            "Alergias: \(Self.text(for: allergies))",
            "Padecimientos: \(Self.text(for: conditions))",
            "Medicamentos: \(Self.text(for: medications))",
        ].joined(separator: " · ")
    }

    static func text(for list: [String]) -> String {
        list.isEmpty ? "Sin información" : list.joined(separator: ", ")
    }
}

extension MedicalProfile: Codable {
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case bloodType = "blood_type"
        case allergies, conditions, medications, contacts
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decodeIfPresent(UUID.self, forKey: .userID)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        dateOfBirth = try c.decodeIfPresent(String.self, forKey: .dateOfBirth)
            .flatMap { Self.dayFormatter.date(from: $0) }
        bloodType = (try? c.decode(BloodType.self, forKey: .bloodType)) ?? .unknown
        allergies = try c.decodeIfPresent([String].self, forKey: .allergies) ?? []
        conditions = try c.decodeIfPresent([String].self, forKey: .conditions) ?? []
        medications = try c.decodeIfPresent([String].self, forKey: .medications) ?? []
        contacts = try c.decodeIfPresent([EmergencyContact].self, forKey: .contacts) ?? []
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
            .flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(userID, forKey: .userID)
        try c.encode(fullName, forKey: .fullName)
        try c.encodeIfPresent(dateOfBirth.map { Self.dayFormatter.string(from: $0) }, forKey: .dateOfBirth)
        try c.encode(bloodType, forKey: .bloodType)
        try c.encode(allergies, forKey: .allergies)
        try c.encode(conditions, forKey: .conditions)
        try c.encode(medications, forKey: .medications)
        try c.encode(contacts, forKey: .contacts)
        try c.encodeIfPresent(updatedAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .updatedAt)
    }

    static var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}

extension MedicalProfile {
    static let sample = MedicalProfile(
        fullName: "María López",
        dateOfBirth: dayFormatter.date(from: "1958-03-14"),
        bloodType: .oPositive,
        allergies: ["Penicilina"],
        conditions: ["Asma"],
        medications: ["Salbutamol"],
        contacts: [EmergencyContact(name: "Ana López", relationship: "Hija", phone: "8112345678")]
    )
}
