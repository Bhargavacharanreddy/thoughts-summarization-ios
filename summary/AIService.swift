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
    let cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let start = cleaned.firstIndex(of: "["),
          let end = cleaned.lastIndex(of: "]") else {
        throw AIError.parseError
    }
    let jsonStr = String(cleaned[start...end])
    guard let data = jsonStr.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        throw AIError.parseError
    }
    return array.compactMap { dict -> CategoryResult? in
        guard let name = dict["name"] as? String,
              let indices = dict["indices"] as? [Int] else { return nil }
        let valid = indices.filter { $0 >= 0 && $0 < thoughtCount }
        return CategoryResult(name: name, thoughtIndices: valid)
    }
}
