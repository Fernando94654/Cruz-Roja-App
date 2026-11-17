import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Uses the on-device model when available and falls back to keyword rules otherwise
@MainActor
final class FallbackReportExtractor: ReportExtracting {
    private let rules = RuleBasedReportExtractor()
    // Holds a FoundationModelReportExtractor; typed loosely because it only exists on iOS 26
    private var model: ReportExtracting?

    /// Loads the on-device model ahead of time when it is available.
    func prewarm() {
        Log.ai.info("Availability on prewarm: \(self.availabilityDescription(), privacy: .public)")
        if availableModel() != nil { model?.prewarm() }
    }

    /// Fills the report with the model, falling back to keyword rules.
    func extract(_ text: String) async throws -> ExtractedFields {
        var reason = unavailableReason()
        Log.ai.info("Availability: \(self.availabilityDescription(), privacy: .public)")
        if reason == nil, let model = availableModel() {
            do {
                return try await model.extract(text)
            } catch {
                Log.ai.error("Model failed: \(String(reflecting: error), privacy: .public)")
                reason = Self.reason(for: error)
            }
        } else {
            Log.ai.notice("Using rules: \(reason ?? "unknown", privacy: .public)")
        }
        var fields = rules.fields(from: text)
        fields.source = .rules(reason: reason)
        return fields
    }

    // User-facing reason for a generation error, naming the error kind to ease debugging
    private static func reason(for error: Error) -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation: return "el filtro de seguridad de Apple rechazó el texto"
            case .unsupportedLanguageOrLocale: return "el idioma del dispositivo no está soportado por la IA"
            case .assetsUnavailable: return "el modelo no está listo en este dispositivo"
            case .exceededContextWindowSize: return "el texto es demasiado largo"
            case .unsupportedGuide: return "el formato pedido al modelo no es compatible"
            case .decodingFailure: return "la IA respondió en un formato inválido"
            default: return "la IA no pudo procesar el texto (\(String(describing: error)))"
            }
        }
        #endif
        return "la IA no pudo procesar el texto (\(error.localizedDescription))"
    }

    // Raw availability value for the logs
    private func availabilityDescription() -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return String(describing: SystemLanguageModel.default.availability)
        }
        return "iOS < 26"
        #else
        return "FoundationModels not in SDK"
        #endif
    }

    private func availableModel() -> ReportExtracting? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            if model == nil { model = FoundationModelReportExtractor() }
            return model
        }
        #endif
        return nil
    }

    // User-facing reason the on-device model can't be used, or nil when it can
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
