import Foundation

struct Fuente: Identifiable, Hashable {
    let id = UUID()
    let documento: String
    let pagina: Int
    let fragmento: String
}

struct Respuesta: Identifiable, Hashable {
    let id = UUID()
    let texto: String
    let emergencia: Emergencia?
    let fuentes: [Fuente]
}

// de mentira: busca palabras clave en lugar de un RAG real sobre los manuales de Cruz Roja
struct Asistente {
    let manual = "Manual de Primeros Auxilios (demo)"

    func responder(_ pregunta: String) async -> Respuesta {
        try? await Task.sleep(for: .seconds(1.4))
        return buscar(pregunta)
    }

    func buscar(_ pregunta: String) -> Respuesta {
        let texto = pregunta.lowercased()
        let coincidencia = emergencias
            .map { e in (e, e.palabras.filter { texto.contains($0) }.count) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0

        guard let e = coincidencia else {
            return Respuesta(
                texto: "No encontré una guía específica. Mantén la calma, revisa que el lugar sea seguro y dime si la persona respira, si sangra o si responde.",
                emergencia: nil,
                fuentes: [Fuente(documento: manual, pagina: 8, fragmento: "Revisar, llamar y atender.")]
            )
        }

        let fuentes = e.pasos.prefix(2).enumerated().map { i, paso in
            Fuente(documento: manual, pagina: e.pagina + i, fragmento: paso.instruccion)
        }
        return Respuesta(
            texto: "Parece un caso de \(e.titulo.lowercased()). Primero: \(e.pasos[0].instruccion) Te puedo guiar paso a paso por voz mientras llega la ambulancia.",
            emergencia: e,
            fuentes: fuentes
        )
    }
}
