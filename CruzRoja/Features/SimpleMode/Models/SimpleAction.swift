import Foundation

/// One big button on the simple mode home screen.
enum SimpleAction: Hashable, Sendable {
    case report
    case call911
    case callContact(name: String, relationship: String, phone: String)
    case showMedicalQR

    // Only the first contacts get their own button so the screen stays short
    static let maxContacts = 2

    /// Buttons in a fixed order: report, 911, up to two contacts, and the medical QR when there is a profile.
    static func actions(for profile: MedicalProfile?) -> [SimpleAction] {
        var actions: [SimpleAction] = [.report, .call911]
        guard let profile else { return actions }
        let contacts = profile.contacts
            .map { (name: $0.name.trimmingCharacters(in: .whitespaces),
                    relationship: $0.relationship.trimmingCharacters(in: .whitespaces),
                    phone: MedicalProfile.digitsOnly($0.phone)) }
            .filter { !$0.name.isEmpty && !$0.phone.isEmpty }
            .prefix(maxContacts)
        actions += contacts.map { .callContact(name: $0.name, relationship: $0.relationship, phone: $0.phone) }
        actions.append(.showMedicalQR)
        return actions
    }

    var title: String {
        switch self {
        case .report: "Reportar emergencia"
        case .call911: "Llamar al 911"
        case let .callContact(name, relationship, _):
            relationship.isEmpty ? "Llamar a \(name)" : "Llamar a \(name) (\(relationship))"
        case .showMedicalQR: "Mostrar mi información médica"
        }
    }

    var systemImage: String {
        switch self {
        case .report: "exclamationmark.triangle.fill"
        case .call911: "phone.fill"
        case .callContact: "person.fill"
        case .showMedicalQR: "qrcode"
        }
    }

    // Read by VoiceOver after the title
    var hint: String {
        switch self {
        case .report: "Te pediremos confirmar y tendrás 5 segundos para cancelar antes de enviar tu ubicación a Cruz Roja."
        case .call911: "Abre una llamada al número de emergencias."
        case .callContact: "Abre una llamada a tu contacto de emergencia."
        case .showMedicalQR: "Muestra un código QR con tu información médica para el paramédico."
        }
    }

    // Emergency buttons are red; the rest use the high-contrast neutral style
    var isEmergency: Bool {
        switch self {
        case .report, .call911: true
        case .callContact, .showMedicalQR: false
        }
    }

    // Phone call for the call buttons, nil for the rest
    var phoneURL: URL? {
        switch self {
        case .call911: URL(string: "tel://\(CalmSafety.emergencyNumber)")
        case let .callContact(_, _, phone): URL(string: "tel://\(phone)")
        case .report, .showMedicalQR: nil
        }
    }
}
