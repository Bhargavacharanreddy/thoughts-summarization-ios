import Foundation

struct CategoryResult {
    let name: String
    let thoughtIndices: [Int]
}

protocol AIService {
    var name: String { get }
    func categorize(thoughts: [String]) async throws -> [CategoryResult]
    func summarize(thoughts: [String], forCategory category: String?) async throws -> String
    func dailySummary(thoughts: [String]) async throws -> String
    func cleanTranscript(_ text: String) async throws -> String
    func generateSummaryImage(summary: String) async throws -> Data?
}

extension AIService {
    func cleanTranscript(_ text: String) async throws -> String { text }
    func generateSummaryImage(summary: String) async throws -> Data? { nil }
}

enum AIError: Error, LocalizedError {
    case parseError
    case unavailable(String)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .parseError: return "Failed to parse AI response."
        case .unavailable(let reason): return "AI unavailable: \(reason)"
        case .noAPIKey: return "API key not configured. Add it in Settings."
        }
    }
}

// Shared JSON parser for OpenAI/Claude category responses
func parseCategoryJSON(_ json: String, thoughtCount: Int) throws -> [CategoryResult] {
    // Strip markdown code fences if present (```json ... ```)
    var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
    if let fenceStart = cleaned.range(of: "```"),
       let fenceEnd = cleaned.range(of: "```", options: .backwards),
       fenceStart.lowerBound != fenceEnd.lowerBound {
        cleaned = String(cleaned[fenceStart.upperBound..<fenceEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip optional "json" language tag on the opening fence
        if cleaned.hasPrefix("json") { cleaned = String(cleaned.dropFirst(4)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Find the JSON array by locating [{ ... }] — more reliable than bare [ ]
    // because model prose may contain brackets (e.g. "your [thoughts]")
    guard let startRange = cleaned.range(of: "[{"),
          let endRange = cleaned.range(of: "}]", options: .backwards) else {
        // Fallback: try bare [ ]
        guard let s = cleaned.firstIndex(of: "["),
              let e = cleaned.lastIndex(of: "]") else { throw AIError.parseError }
        return try parseArray(String(cleaned[s...e]), thoughtCount: thoughtCount)
    }

    // Use half-open range (..<) so upperBound == endIndex doesn't crash
    let jsonStr = String(cleaned[startRange.lowerBound..<endRange.upperBound])
    return try parseArray(jsonStr, thoughtCount: thoughtCount)
}

private func parseArray(_ jsonStr: String, thoughtCount: Int) throws -> [CategoryResult] {
    guard let data = jsonStr.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        throw AIError.parseError
    }
    return array.compactMap { dict -> CategoryResult? in
        guard let name = dict["name"] as? String else { return nil }
        let rawIndices = dict["indices"] as? [Any] ?? []
        let indices: [Int] = rawIndices.compactMap {
            if let i = $0 as? Int { return i }
            if let s = $0 as? String { return Int(s) }
            return nil
        }
        let valid = indices.filter { $0 >= 0 && $0 < thoughtCount }
        return CategoryResult(name: name, thoughtIndices: valid)
    }
}
