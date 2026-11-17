#if canImport(FoundationModels)
import Foundation
import FoundationModels

// Respuesta que debe dar la IA del iPhone; vacío o 0 = no se mencionó
@available(iOS 26.0, *)
@Generable
struct ProfileDraft {
    @Guide(description: "Edad en años si la persona la dijo; 0 si no la dijo.", .range(0...120))
    var age: Int

    @Guide(description: "Fecha de nacimiento completa en formato AAAA-MM-DD si la dijo (por ejemplo '1958-03-14'); vacío si no la dijo completa.")
    var birthDate: String

    @Guide(description: "Tipo de sangre si lo dijo; vacío si no lo dijo.", .anyOf(["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]))
    var bloodType: String

    @Guide(description: "true solo si dijo claramente que no tiene alergias.")
    var noKnownAllergies: Bool

    @Guide(description: "Cada alergia que mencionó, en pocas palabras y con mayúscula inicial (por ejemplo 'Penicilina').")
    var allergies: [String]

    @Guide(description: "Cada enfermedad o padecimiento que mencionó, con mayúscula inicial (por ejemplo 'Diabetes', 'Hipertensión'). 'Soy diabético' es 'Diabetes'.")
    var conditions: [String]

    @Guide(description: "Cada medicamento que mencionó, con la dosis y la frecuencia si las dijo (por ejemplo 'Metformina 850 mg, 2 veces al día').")
    var medications: [String]

    @Guide(description: "Contactos de emergencia que mencionó con su teléfono.")
    var contacts: [ContactDraft]
}

@available(iOS 26.0, *)
@Generable
struct ContactDraft {
    @Guide(description: "Nombre de la persona; si no lo dijo, su parentesco.")
    var name: String

    @Guide(description: "Parentesco con mayúscula inicial, por ejemplo 'Hija' o 'Esposo'.")
    var relationship: String

    @Guide(description: "Teléfono a 10 dígitos, solo números.")
    var phone: String
}

// Acomoda lo dictado en los campos del perfil con la IA del iPhone; nada sale del teléfono
@available(iOS 26.0, *)
@MainActor
final class FoundationModelProfileExtractor: ProfileExtracting {
    private static let instructions = """
        Ayudas a llenar el perfil médico de una app de la Cruz Roja Mexicana. Recibes lo que una persona \
        dictó sobre su salud o la de un familiar, a veces con errores o sin acentos. Acomoda cada dato en su \
        campo usando solo lo que la persona dijo. No inventes, no supongas y no diagnostiques: no agregues \
        enfermedades, alergias ni medicamentos que no se mencionen. Responde siempre en español.
        """

    func extract(_ text: String) async throws -> ProfileFields {
        let session = LanguageModelSession(instructions: Self.instructions)
        Log.ai.info("Profile prompt (\(text.count) chars)")
        do {
            let draft = try await session.respond(to: "Lo que dictó la persona: \(text)", generating: ProfileDraft.self).content
            return Self.fields(from: draft)
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            // Los temas de salud a veces activan el filtro; se reintenta en modo texto, que es más permisivo
            Log.ai.notice("Guardrails blocked the profile; retrying in permissive text mode")
            return try await permissiveExtract(text)
        }
    }

    private func permissiveExtract(_ text: String) async throws -> ProfileFields {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: Self.instructions + " " + Self.jsonFormat)
        let answer = try await session.respond(to: "Lo que dictó la persona: \(text)").content
        guard let open = answer.firstIndex(of: "{"), let close = answer.lastIndex(of: "}"),
              let json = try? JSONDecoder().decode(ProfileJSON.self, from: Data(answer[open...close].utf8))
        else { throw InvalidModelAnswer() }

        var fields = ProfileFields(source: .ai)
        fields.age = json.age.flatMap { (1...120).contains($0) ? $0 : nil }
        fields.dateOfBirth = json.birthDate.flatMap { ProfileFields.birthDate(iso: $0) }
        fields.bloodType = json.bloodType.flatMap { BloodType(rawValue: $0) }
        fields.noKnownAllergies = json.noKnownAllergies ?? false
        fields.allergies = Self.clean(json.allergies ?? [])
        fields.conditions = Self.clean(json.conditions ?? [])
        fields.medications = Self.clean(json.medications ?? [])
        fields.contacts = Self.contacts((json.contacts ?? []).map { ($0.name ?? "", $0.relationship ?? "", $0.phone ?? "") })
        return fields
    }

    private static let jsonFormat = """
        Responde únicamente con un objeto JSON con estas claves: "age" (número o null), \
        "birthDate" (fecha de nacimiento "AAAA-MM-DD" o null), \
        "bloodType" ("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-" o null), "noKnownAllergies" (true o false), \
        "allergies", "conditions" y "medications" (listas de textos), y "contacts" (lista de objetos con \
        "name", "relationship" y "phone").
        """

    private struct InvalidModelAnswer: LocalizedError {
        var errorDescription: String? { "respuesta en formato inválido" }
    }

    private struct ProfileJSON: Decodable {
        struct Contact: Decodable {
            let name: String?
            let relationship: String?
            let phone: String?
        }
        let age: Int?
        let birthDate: String?
        let bloodType: String?
        let noKnownAllergies: Bool?
        let allergies: [String]?
        let conditions: [String]?
        let medications: [String]?
        let contacts: [Contact]?
    }

    private static func fields(from draft: ProfileDraft) -> ProfileFields {
        var fields = ProfileFields(source: .ai)
        fields.age = draft.age > 0 ? draft.age : nil
        fields.dateOfBirth = ProfileFields.birthDate(iso: draft.birthDate)
        fields.bloodType = BloodType(rawValue: draft.bloodType)
        fields.noKnownAllergies = draft.noKnownAllergies && draft.allergies.isEmpty
        fields.allergies = clean(draft.allergies)
        fields.conditions = clean(draft.conditions)
        fields.medications = clean(draft.medications)
        fields.contacts = contacts(draft.contacts.map { ($0.name, $0.relationship, $0.phone) })
        return fields
    }

    // Solo contactos con teléfono válido de 10 dígitos
    // Cada contacto llega como (nombre, parentesco, teléfono)
    private static func contacts(_ list: [(String, String, String)]) -> [EmergencyContact] {
        list.compactMap { rawName, rawRelationship, phone in
            let digits = MedicalProfile.digitsOnly(phone)
            guard digits.count == 10 else { return nil }
            let relationship = rawRelationship.trimmingCharacters(in: .whitespaces)
            let name = rawName.trimmingCharacters(in: .whitespaces)
            return EmergencyContact(name: name.isEmpty ? relationship : name,
                                    relationship: relationship.isEmpty ? "Contacto" : relationship,
                                    phone: digits)
        }
    }

    private static func clean(_ list: [String]) -> [String] {
        MedicalProfile.cleanList(list)
    }
}
#endif
