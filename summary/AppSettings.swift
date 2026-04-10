import Foundation
import FoundationModels

@Observable
class AppSettings {
    enum AIProvider: String, CaseIterable, Identifiable {
        case appleIntelligence = "Apple Intelligence"
        case openAI = "OpenAI"
        case claude = "Claude"
        var id: String { rawValue }
    }

    var selectedProvider: AIProvider {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider") }
    }
    var openAIKey: String {
        didSet { UserDefaults.standard.set(openAIKey, forKey: "openAIKey") }
    }
    var claudeKey: String {
        didSet { UserDefaults.standard.set(claudeKey, forKey: "claudeKey") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "selectedProvider") ?? ""
        selectedProvider = AIProvider(rawValue: raw) ?? .appleIntelligence
        openAIKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        claudeKey = UserDefaults.standard.string(forKey: "claudeKey") ?? ""
    }

    func makeAIService() -> (any AIService)? {
        switch selectedProvider {
        case .appleIntelligence:
            if #available(iOS 26, *) {
                guard case .available = SystemLanguageModel.default.availability else {
                    return nil
                }
                return AppleIntelligenceService()
            }
            return nil
        case .openAI:
            guard !openAIKey.isEmpty else { return nil }
            return OpenAIService(apiKey: openAIKey)
        case .claude:
            guard !claudeKey.isEmpty else { return nil }
            return ClaudeService(apiKey: claudeKey)
        }
    }

    @available(iOS 26, *)
    var appleIntelligenceAvailability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }
}
