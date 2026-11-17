import Foundation

extension MedicalProfile {
    // Junta lo dictado con lo que ya había: agrega sin borrar ni repetir.
    // Regresa el perfil nuevo, la lista de lo que se agregó y un aviso sobre la edad, para que la persona lo revise.
    func merging(_ fields: ProfileFields) -> (profile: MedicalProfile, added: [String], ageNote: String?) {
        var copy = self
        var added: [String] = []
        var ageNote: String?

        if let date = fields.dateOfBirth {
            // Dijo su fecha exacta
            if date != copy.dateOfBirth {
                copy.dateOfBirth = date
                added.append("Fecha de nacimiento: \(date.formatted(date: .long, time: .omitted))")
            }
        } else if let age = fields.age, copy.age() != age {
            if copy.dateOfBirth == nil {
                // Solo dijo su edad: fecha aproximada para que la edad salga bien, y se le pide corregirla
                copy.dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: Date())
                added.append("Edad: \(age) años")
                ageNote = "Pusimos una fecha aproximada para que tu edad sea \(age) años. Cámbiala por tu fecha de nacimiento real."
            } else if let current = copy.age() {
                // No se cambia una fecha que ya estaba; solo se avisa
                ageNote = "Dijiste \(age) años, pero la fecha de nacimiento guardada da \(current) años. Revísala."
            }
        }

        if let bloodType = fields.bloodType, bloodType != copy.bloodType {
            copy.bloodType = bloodType
            added.append("Tipo de sangre: \(bloodType.label)")
        }

        let newAllergies = Self.newItems(fields.allergies, notIn: copy.allergies)
        if !newAllergies.isEmpty {
            // Si había "Sin alergias conocidas" y ahora dijo una alergia, se quita
            copy.allergies = copy.allergies.filter { $0 != Self.noAllergies } + newAllergies
            added.append("Alergias: \(newAllergies.joined(separator: ", "))")
        } else if fields.noKnownAllergies, copy.allergies.isEmpty {
            copy.allergies = [Self.noAllergies]
            added.append("Alergias: \(Self.noAllergies)")
        }

        let newConditions = Self.newItems(fields.conditions, notIn: copy.conditions)
        if !newConditions.isEmpty {
            copy.conditions = copy.conditions.filter { $0 != Self.noConditions } + newConditions
            added.append("Padecimientos: \(newConditions.joined(separator: ", "))")
        }

        let newMedications = Self.newItems(fields.medications, notIn: copy.medications)
        if !newMedications.isEmpty {
            copy.medications = copy.medications.filter { $0 != Self.noMedications } + newMedications
            added.append("Medicamentos: \(newMedications.joined(separator: ", "))")
        }

        let knownPhones = Set(copy.contacts.map { Self.digitsOnly($0.phone) })
        let room = max(Self.maxContacts - copy.contacts.count, 0)
        let newContacts = fields.contacts.filter { !knownPhones.contains(Self.digitsOnly($0.phone)) }.prefix(room)
        if !newContacts.isEmpty {
            copy.contacts += newContacts
            added.append("Contactos: " + newContacts.map { "\($0.name) (\($0.relationship))" }.joined(separator: ", "))
        }

        return (copy, added, ageNote)
    }

    // Lo dictado que todavía no estaba en la lista (sin importar mayúsculas)
    private static func newItems(_ items: [String], notIn existing: [String]) -> [String] {
        let known = Set(existing.map { $0.lowercased() })
        return cleanList(items).filter { !known.contains($0.lowercased()) }
    }
}
