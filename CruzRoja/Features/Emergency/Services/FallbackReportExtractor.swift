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

    func prewarm() {
        if availableModel() != nil { model?.prewarm() }
    }

    func extract(_ text: String) async throws -> ExtractedFields {
        var reason = unavailableReason()
        if reason == nil, let model = availableModel() {
            do {
                return try await model.extract(text)
            } catch {
                reason = "la IA no pudo procesar el texto"
            }
        }
        var fields = rules.fields(from: text)
        fields.source = .rules(reason: reason)
        return fields
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
