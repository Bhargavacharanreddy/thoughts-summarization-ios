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
        let messages: [[String: String]] = [["role": "user", "content": prompt]]
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": messages
        ]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            var apiMsg = "HTTP \(http.statusCode)"
            if let json = json,
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                apiMsg = message
            }
            throw AIError.unavailable(apiMsg)
        }

        // Parse Claude response content
        if let json = json,
           let content = json["content"] as? [[String: Any]],
           let firstContent = content.first,
           let text = firstContent["text"] as? String {
            return text
        }
        throw AIError.parseError
    }

    func categorize(thoughts: [String]) async throws -> [CategoryResult] {
        let numbered = thoughts.enumerated()
            .map { "\($0.offset). \($0.element)" }
            .joined(separator: "\n")
        let prompt = """
        Group the following thoughts into meaningful categories.

        Rules:
        - Return ONLY a raw JSON array. No markdown, no code fences, no explanation.
        - Each element: {"name":"Category Name","indices":[0,1,2]}
        - Indices are zero-based integers matching the thought numbers below.
        - Every thought must appear in exactly one category.
        - Be concise and fast.

        Example output: [{"name":"Work","indices":[0,2]},{"name":"Health","indices":[1]}]

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

    func cleanTranscript(_ text: String) async throws -> String {
        let prompt = """
        Clean up this voice-to-text transcription. Remove filler words (um, uh, like, you know, so), fix grammar, and make it clear and concise while preserving the original meaning. Return only the cleaned text with no explanation or preamble.

        Transcription: \(text)
        """
        return try await complete(prompt)
    }
}
