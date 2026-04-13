import Foundation

struct CategoryResult {
    let name: String
    let thoughtIndices: [Int]
}

struct TodoResult {
    let title: String
    let notes: String
    let quadrant: String  // matches EisenhowerQuadrant raw values
}

protocol AIService {
    var name: String { get }
    func categorize(thoughts: [String]) async throws -> [CategoryResult]
    func summarize(thoughts: [String], forCategory category: String?) async throws -> String
    func dailySummary(thoughts: [String]) async throws -> String
    func cleanTranscript(_ text: String) async throws -> String
    func generateSummaryImage(summary: String) async throws -> Data?
    func generateTodos(thoughts: [String], categories: [String]) async throws -> [TodoResult]
}

extension AIService {
    func cleanTranscript(_ text: String) async throws -> String { text }
    func generateSummaryImage(summary: String) async throws -> Data? { nil }
    func generateTodos(thoughts: [String], categories: [String]) async throws -> [TodoResult] { [] }
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

// MARK: - Category JSON parser

func parseCategoryJSON(_ json: String, thoughtCount: Int) throws -> [CategoryResult] {
    var cleaned = stripFences(json)

    guard let startRange = cleaned.range(of: "[{"),
          let endRange = cleaned.range(of: "}]", options: .backwards) else {
        guard let s = cleaned.firstIndex(of: "["),
              let e = cleaned.lastIndex(of: "]") else { throw AIError.parseError }
        return try parseCategoryArray(String(cleaned[s...e]), thoughtCount: thoughtCount)
    }
    let jsonStr = String(cleaned[startRange.lowerBound..<endRange.upperBound])
    return try parseCategoryArray(jsonStr, thoughtCount: thoughtCount)
}

private func parseCategoryArray(_ jsonStr: String, thoughtCount: Int) throws -> [CategoryResult] {
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

// MARK: - Todo JSON parser

func parseTodoJSON(_ json: String) throws -> [TodoResult] {
    var cleaned = stripFences(json)

    guard let startRange = cleaned.range(of: "[{"),
          let endRange = cleaned.range(of: "}]", options: .backwards) else {
        guard let s = cleaned.firstIndex(of: "["),
              let e = cleaned.lastIndex(of: "]") else { throw AIError.parseError }
        return try parseTodoArray(String(cleaned[s...e]))
    }
    let jsonStr = String(cleaned[startRange.lowerBound..<endRange.upperBound])
    return try parseTodoArray(jsonStr)
}

private func parseTodoArray(_ jsonStr: String) throws -> [TodoResult] {
    guard let data = jsonStr.data(using: .utf8),
          let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        throw AIError.parseError
    }
    return array.compactMap { dict -> TodoResult? in
        guard let title = dict["title"] as? String, !title.isEmpty else { return nil }
        let notes = dict["notes"] as? String ?? ""
        let quadrant = dict["quadrant"] as? String ?? "notUrgentNotImportant"
        return TodoResult(title: title, notes: notes, quadrant: quadrant)
    }
}

// MARK: - Shared helpers

private func stripFences(_ json: String) -> String {
    var cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
    if let fenceStart = cleaned.range(of: "```"),
       let fenceEnd = cleaned.range(of: "```", options: .backwards),
       fenceStart.lowerBound != fenceEnd.lowerBound {
        cleaned = String(cleaned[fenceStart.upperBound..<fenceEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("json") { cleaned = String(cleaned.dropFirst(4)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return cleaned
}
