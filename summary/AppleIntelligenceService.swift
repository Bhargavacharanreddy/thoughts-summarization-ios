import FoundationModels

@Generable
struct CategorizationOutput {
    @Guide(description: "List of thought categories")
    var categories: [CategoryItem]
}

@Generable
struct CategoryItem {
    @Guide(description: "A short descriptive label for this group of thoughts")
    var name: String
    @Guide(description: "Zero-based indices of thoughts that belong in this category")
    var indices: [Int]
}

@available(iOS 26, *)
class AppleIntelligenceService: AIService {
    let name = "Apple Intelligence"

    func categorize(thoughts: [String]) async throws -> [CategoryResult] {
        let session = LanguageModelSession()
        let numbered = thoughts.enumerated()
            .map { "\($0.offset). \($0.element)" }
            .joined(separator: "\n")
        let prompt = """
        Group the following thoughts into meaningful categories. \
        Each thought belongs to exactly one category.

        Thoughts:
        \(numbered)
        """
        let response = try await session.respond(to: prompt, generating: CategorizationOutput.self)
        return response.content.categories.map {
            CategoryResult(name: $0.name, thoughtIndices: $0.indices)
        }
    }

    func summarize(thoughts: [String], forCategory category: String?) async throws -> String {
        let session = LanguageModelSession()
        let context = category.map { " about \($0)" } ?? ""
        let prompt = "Summarize these thoughts\(context) in 2–3 sentences:\n\(thoughts.joined(separator: "\n"))"
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func dailySummary(thoughts: [String]) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        Create a concise daily summary highlighting key themes and insights in 3–5 sentences.

        Thoughts:
        \(thoughts.joined(separator: "\n"))
        """
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func cleanTranscript(_ text: String) async throws -> String {
        let session = LanguageModelSession()
        let prompt = "Clean up this voice-to-text transcription. Remove filler words (um, uh, like, you know, so), fix grammar, and make it clear and concise while preserving the original meaning. Return only the cleaned text with no explanation or preamble.\n\nTranscription: \(text)"
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
