import Foundation

class OpenAIService: AIService {
    let name = "OpenAI"
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.model = model
    }

    private func complete(_ prompt: String, maxTokens: Int = 1024) async throws -> String {
        let messages: [[String: String]] = [["role": "user", "content": prompt]]
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": maxTokens
        ]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Detect API-level errors (bad key, quota, etc.)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            var apiMsg = "HTTP \(http.statusCode)"
            if let json = json,
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                apiMsg = message
            }
            throw AIError.unavailable(apiMsg)
        }

        // Parse the response content
        if let json = json,
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
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
        let response = try await complete(prompt, maxTokens: 512)
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

    // MARK: - Whisper

    func transcribeAudio(fileURL: URL) async throws -> String {
        let audioData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func append(_ string: String) { body.append(string.data(using: .utf8)!) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("whisper-1\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            return ""
        }
        return text
    }

    // MARK: - DALL-E

    func generateSummaryImage(summary: String) async throws -> Data? {
        let truncated = String(summary.prefix(300))
        let prompt = "Abstract, vibrant digital art representing someone's daily thoughts and ideas. Core theme: \(truncated). Style: colorful mind-map aesthetic, dreamy, surreal, thought-provoking, no text."

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "response_format": "url"
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            var apiMsg = "Image generation failed (HTTP \(http.statusCode))"
            if let json = json,
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                apiMsg = message
            }
            throw AIError.unavailable(apiMsg)
        }

        guard let json = json,
              let dataArr = json["data"] as? [[String: Any]],
              let firstItem = dataArr.first,
              let urlString = firstItem["url"] as? String,
              let imageURL = URL(string: urlString) else {
            throw AIError.unavailable("No image returned from DALL-E.")
        }

        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        return imageData
    }
}
