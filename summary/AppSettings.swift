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
