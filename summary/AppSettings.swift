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
        didSet { KeychainStore.set(openAIKey, forKey: "openAIKey") }
    }
    var claudeKey: String {
        didSet { KeychainStore.set(claudeKey, forKey: "claudeKey") }
    }
    /// Providers the user has agreed to send their thoughts to.
    var consentedProviders: Set<AIProvider> {
        didSet { UserDefaults.standard.set(consentedProviders.map(\.rawValue), forKey: "consentedProviders") }
    }

    init() {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: "selectedProvider") ?? ""
        selectedProvider = AIProvider(rawValue: raw) ?? .appleIntelligence
        var consented = Set((defaults.stringArray(forKey: "consentedProviders") ?? []).compactMap(AIProvider.init(rawValue:)))

        // Move keys saved by older versions out of UserDefaults. Anyone who already entered
        // a key chose that provider themselves, so treat it as consent.
        for (key, provider) in [("openAIKey", AIProvider.openAI), ("claudeKey", .claude)] {
            if let legacy = defaults.string(forKey: key) {
                if !legacy.isEmpty {
                    KeychainStore.set(legacy, forKey: key)
                    consented.insert(provider)
                }
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set(consented.map(\.rawValue), forKey: "consentedProviders")
        consentedProviders = consented
        openAIKey = KeychainStore.string(forKey: "openAIKey") ?? ""
        claudeKey = KeychainStore.string(forKey: "claudeKey") ?? ""
    }

    /// Why `makeAIService()` returns nil for the selected provider, in words the user can act on.
    var serviceUnavailableMessage: String {
        switch selectedProvider {
        case .appleIntelligence:
            guard case .unavailable(let reason) = SystemLanguageModel.default.availability else {
                return "Apple Intelligence isn't available right now."
            }
            switch reason {
            case .deviceNotEligible:
                return "This device doesn't support Apple Intelligence. Choose OpenAI or Claude in Settings."
            case .appleIntelligenceNotEnabled:
                return "Turn on Apple Intelligence in the iPhone Settings app, or choose another provider."
            case .modelNotReady:
                return "Apple Intelligence is still downloading. Try again in a few minutes."
            @unknown default:
                return "Apple Intelligence isn't available right now."
            }
        case .openAI, .claude:
            return AIError.noAPIKey.errorDescription ?? ""
        }
    }

    /// Where summary images come from with the selected provider, shown under the Generate Image button.
    var imageSourceDescription: String {
        switch selectedProvider {
        case .appleIntelligence: return "Made on your iPhone with Image Playground"
        case .openAI: return "Made by OpenAI from your summary"
        case .claude: return "Claude can't make images. Switch to Apple Intelligence or OpenAI."
        }
    }

    func hasConsented(to provider: AIProvider) -> Bool {
        provider == .appleIntelligence || consentedProviders.contains(provider)
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
            guard !openAIKey.isEmpty, hasConsented(to: .openAI) else { return nil }
            return OpenAIService(apiKey: openAIKey)
        case .claude:
            guard !claudeKey.isEmpty, hasConsented(to: .claude) else { return nil }
            return ClaudeService(apiKey: claudeKey)
        }
    }

    @available(iOS 26, *)
    var appleIntelligenceAvailability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    // MARK: - API Key Verification

    func testOpenAIKey() async -> Bool {
        guard !openAIKey.isEmpty else { return false }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let messages: [[String: String]] = [["role": "user", "content": "Say ok"]]
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 5
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return false }
        request.httpBody = httpBody
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        if http.statusCode == 200 { return true }
        // Check if error is auth-related
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let errType = error["type"] as? String {
            return errType != "invalid_request_error" && errType != "authentication_error"
        }
        return false
    }

    func testClaudeKey() async -> Bool {
        guard !claudeKey.isEmpty else { return false }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(claudeKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let messages: [[String: String]] = [["role": "user", "content": "Say ok"]]
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 5,
            "messages": messages
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return false }
        request.httpBody = httpBody
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }
}
