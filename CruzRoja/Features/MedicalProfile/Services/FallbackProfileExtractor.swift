import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Usa la IA del iPhone si está disponible; si no, las palabras clave (y dice por qué)
@MainActor
final class FallbackProfileExtractor: ProfileExtracting {
    private let rules = RuleBasedProfileExtractor()
    // Guarda un FoundationModelProfileExtractor; el tipo es general porque solo existe en iOS 26
    private var model: ProfileExtracting?

    func extract(_ text: String) async throws -> ProfileFields {
        var reason = unavailableReason()
        if reason == nil, let model = availableModel() {
            do {
                return try await model.extract(text)
            } catch {
                Log.ai.error("Profile model failed: \(String(reflecting: error), privacy: .public)")
                reason = "la IA no pudo procesar el texto"
            }
        }
        var fields = rules.fields(from: text)
        fields.source = .rules(reason: reason)
        return fields
    }

    private func availableModel() -> ProfileExtracting? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            if model == nil { model = FoundationModelProfileExtractor() }
            return model
        }
        #endif
        return nil
    }

    // Motivo para el usuario de por qué no se usa la IA, o nil si sí se puede
    private func unavailableReason() -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "este dispositivo no soporta Apple Intelligence"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "activa Apple Intelligence en Ajustes"
            case .unavailable(.modelNotReady):
                return "el modelo se está descargando"
            case .unavailable:
                return "Apple Intelligence no está disponible"
            }
        }
        return "requiere iOS 26"
        #else
        return "esta versión de Xcode no incluye la IA de Apple"
        #endif
    }
}
