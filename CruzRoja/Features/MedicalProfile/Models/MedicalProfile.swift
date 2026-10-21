import Foundation

// MARK: - Tipo de sangre

enum TipoSangre: String, Codable, CaseIterable, Identifiable, Sendable {
    case aPositivo = "A+"
    case aNegativo = "A-"
    case bPositivo = "B+"
    case bNegativo = "B-"
    case abPositivo = "AB+"
    case abNegativo = "AB-"
    case oPositivo = "O+"
    case oNegativo = "O-"
    case desconocido

    var id: String { rawValue }

    /// Texto que ve el usuario.
    var etiqueta: String {
        self == .desconocido ? "No lo sé" : rawValue
    }
}

// MARK: - Contacto de emergencia

struct ContactoEmergencia: Codable, Identifiable, Equatable, Hashable, Sendable {
    /// Solo se usa dentro de la app para las listas; no se envía al API.
    var id = UUID()
    var nombre: String
    var parentesco: String
    var telefono: String

    enum CodingKeys: String, CodingKey {
        case nombre, parentesco, telefono
    }

    var telefonoFormateado: String {
        PerfilMedico.formatearTelefono(telefono)
    }
}

// MARK: - Perfil médico

/// Datos médicos del usuario. Es el mismo formato que regresa el API:
/// GET /usuarios/{id}/perfil
struct PerfilMedico: Equatable, Sendable {
    var usuarioID: Int?
    var nombre: String = ""
    var fechaNacimiento: Date?
    var tipoSangre: TipoSangre = .desconocido
    var alergias: [String] = []
    var padecimientos: [String] = []
    var medicamentos: [String] = []
    var contactos: [ContactoEmergencia] = []
    var actualizado: Date?

    static let maximoContactos = 5
}

// MARK: - Validación

extension PerfilMedico {
    /// Deja solo los dígitos de un teléfono: "81 1234-5678" → "8112345678".
    static func soloDigitos(_ texto: String) -> String {
        String(texto.filter { $0.isASCII && $0.isNumber })
    }

    /// Un teléfono en México tiene 10 dígitos.
    static func telefonoValido(_ texto: String) -> Bool {
        soloDigitos(texto).count == 10
    }

    /// "8112345678" → "81 1234 5678". Si no tiene 10 dígitos, lo deja igual.
    static func formatearTelefono(_ texto: String) -> String {
        let d = Array(soloDigitos(texto))
        guard d.count == 10 else { return texto }
        return "\(String(d[0..<2])) \(String(d[2..<6])) \(String(d[6..<10]))"
    }

    /// Mensajes de lo que falta corregir. Vacío si el perfil se puede guardar.
    var erroresDeValidacion: [String] {
        var errores: [String] = []
        if nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errores.append("Escribe el nombre de la persona.")
        }
        if let fecha = fechaNacimiento, fecha > Date() {
            errores.append("La fecha de nacimiento no puede ser futura.")
        }
        if contactos.count > Self.maximoContactos {
            errores.append("Puedes registrar hasta \(Self.maximoContactos) contactos.")
        }
        for (i, contacto) in contactos.enumerated() {
            let numero = "Contacto \(i + 1)"
            if contacto.nombre.trimmingCharacters(in: .whitespaces).isEmpty {
                errores.append("\(numero): escribe su nombre.")
            }
            if contacto.parentesco.trimmingCharacters(in: .whitespaces).isEmpty {
                errores.append("\(numero): escribe el parentesco.")
            }
            if !Self.telefonoValido(contacto.telefono) {
                errores.append("\(numero): el teléfono debe tener 10 dígitos.")
            }
        }
        return errores
    }

    var esValido: Bool { erroresDeValidacion.isEmpty }

    /// Copia lista para guardar: sin espacios de más, sin elementos vacíos
    /// ni repetidos, y con los teléfonos solo en dígitos.
    func limpio() -> PerfilMedico {
        var copia = self
        copia.nombre = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        copia.alergias = Self.limpiarLista(alergias)
        copia.padecimientos = Self.limpiarLista(padecimientos)
        copia.medicamentos = Self.limpiarLista(medicamentos)
        copia.contactos = contactos.map { contacto in
            var c = contacto
            c.nombre = c.nombre.trimmingCharacters(in: .whitespaces)
            c.parentesco = c.parentesco.trimmingCharacters(in: .whitespaces)
            c.telefono = Self.soloDigitos(c.telefono)
            return c
        }
        return copia
    }

    static func limpiarLista(_ lista: [String]) -> [String] {
        var vistos = Set<String>()
        return lista.compactMap { elemento in
            let texto = elemento.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !texto.isEmpty, vistos.insert(texto.lowercased()).inserted else { return nil }
            return texto
        }
    }

    /// Edad en años cumplidos a la fecha indicada.
    func edad(al dia: Date = Date()) -> Int? {
        guard let fechaNacimiento else { return nil }
        return Calendar.current.dateComponents([.year], from: fechaNacimiento, to: dia).year
    }
}

// MARK: - Textos para el QR y el reporte

extension PerfilMedico {
    /// Texto que va dentro del código QR. Cualquier cámara lo lee sin internet.
    func textoQR(incluirContactos: Bool) -> String {
        var lineas = ["CRUZ ROJA · PERFIL MÉDICO"]
        lineas.append("Nombre: \(nombre)")
        if let edad = edad() {
            lineas.append("Edad: \(edad) años")
        }
        lineas.append("Sangre: \(tipoSangre.etiqueta)")
        lineas.append("Alergias: \(Self.texto(de: alergias))")
        lineas.append("Padecimientos: \(Self.texto(de: padecimientos))")
        lineas.append("Medicamentos: \(Self.texto(de: medicamentos))")
        if incluirContactos {
            for c in contactos {
                lineas.append("Contacto: \(c.nombre) (\(c.parentesco)) \(c.telefonoFormateado)")
            }
        }
        return lineas.joined(separator: "\n")
    }

    /// Resumen de una línea para adjuntar al reporte de emergencia.
    /// Ejemplo: "Sangre O+ · Alergias: Penicilina · Padecimientos: Asma · Medicamentos: Salbutamol"
    var resumenParaReporte: String {
        [
            "Sangre \(tipoSangre.etiqueta)",
            "Alergias: \(Self.texto(de: alergias))",
            "Padecimientos: \(Self.texto(de: padecimientos))",
            "Medicamentos: \(Self.texto(de: medicamentos))",
        ].joined(separator: " · ")
    }

    static func texto(de lista: [String]) -> String {
        lista.isEmpty ? "Ninguno registrado" : lista.joined(separator: ", ")
    }
}

// MARK: - JSON

// El API usa nombres en snake_case, la fecha de nacimiento como "AAAA-MM-DD"
// y la fecha de actualización en ISO 8601. Se declara en una extensión para
// conservar el inicializador por miembros (PerfilMedico(nombre: ...)).
extension PerfilMedico: Codable {
    enum CodingKeys: String, CodingKey {
        case usuarioID = "usuario_id"
        case nombre
        case fechaNacimiento = "fecha_nacimiento"
        case tipoSangre = "tipo_sangre"
        case alergias, padecimientos, medicamentos, contactos, actualizado
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        usuarioID = try c.decodeIfPresent(Int.self, forKey: .usuarioID)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        fechaNacimiento = try c.decodeIfPresent(String.self, forKey: .fechaNacimiento)
            .flatMap { Self.formatoDia.date(from: $0) }
        // Si el API agrega un valor nuevo, no truena: queda como "desconocido".
        tipoSangre = (try? c.decode(TipoSangre.self, forKey: .tipoSangre)) ?? .desconocido
        alergias = try c.decodeIfPresent([String].self, forKey: .alergias) ?? []
        padecimientos = try c.decodeIfPresent([String].self, forKey: .padecimientos) ?? []
        medicamentos = try c.decodeIfPresent([String].self, forKey: .medicamentos) ?? []
        contactos = try c.decodeIfPresent([ContactoEmergencia].self, forKey: .contactos) ?? []
        actualizado = try c.decodeIfPresent(String.self, forKey: .actualizado)
            .flatMap { Self.formatoISO.date(from: $0) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(usuarioID, forKey: .usuarioID)
        try c.encode(nombre, forKey: .nombre)
        try c.encodeIfPresent(fechaNacimiento.map { Self.formatoDia.string(from: $0) }, forKey: .fechaNacimiento)
        try c.encode(tipoSangre, forKey: .tipoSangre)
        try c.encode(alergias, forKey: .alergias)
        try c.encode(padecimientos, forKey: .padecimientos)
        try c.encode(medicamentos, forKey: .medicamentos)
        try c.encode(contactos, forKey: .contactos)
        try c.encodeIfPresent(actualizado.map { Self.formatoISO.string(from: $0) }, forKey: .actualizado)
    }

    /// "1958-03-14"
    static var formatoDia: DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// "2026-10-21T18:14:07Z"
    static var formatoISO: ISO8601DateFormatter {
        ISO8601DateFormatter()
    }
}
