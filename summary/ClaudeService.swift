import Foundation

class ClaudeService: AIService {
    let name = "Claude"
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "claude-haiku-4-5-20251001") {
        self.apiKey = apiKey
        self.model = model
    }

    private func complete(_ prompt: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        return content?.first?["text"] as? String ?? ""
    }

    func categorize(thoughts: [String]) async throws -> [CategoryResult] {
        let numbered = thoughts.enumerated()
            .map { "\($0.offset). \($0.element)" }
            .joined(separator: "\n")
        let prompt = """
        Group these thoughts into meaningful categories.
        Return ONLY a JSON array, no extra text:
        [{"name":"Category Name","indices":[0,1,2]},...]

        Thoughts:
        \(numbered)
        """
        let response = try await complete(prompt)
        return try parseCategoryJSON(response, thoughtCount: thoughts.count)
    }

    func summarize(thoughts: [String], forCategory category: String?) async throws -> String {
        let context = category.map { " about \($0)" } ?? ""
        let prompt = "Summarize these thoughts\(context) in 2–3 sentences:\n\(thoughts.joined(separator: "\n"))"
        return try await complete(prompt)
    }

    func dailySummary(thoughts: [String]) async throws -> String {
        let prompt = """
        Create a concise daily summary highlighting key themes and insights in 3–5 sentences:
        \(thoughts.joined(separator: "\n"))
        """
        return try await complete(prompt)
    }
}
