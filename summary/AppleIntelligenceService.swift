import FoundationModels
import ImagePlayground
import UIKit

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

@Generable
struct TodoOutput {
    @Guide(description: "List of actionable todo items derived from the thoughts")
    var todos: [TodoItemGenerable]
}

@Generable
struct TodoItemGenerable {
    @Guide(description: "Short, actionable task title")
    var title: String
    @Guide(description: "Optional additional context or detail (empty string if none)")
    var notes: String
    @Guide(description: "Eisenhower quadrant", .anyOf(EisenhowerQuadrant.allCases.map(\.rawValue)))
    var quadrant: String
}

@available(iOS 26, *)
class AppleIntelligenceService: AIService {
    let name = "Apple Intelligence"

    /// The on-device model has a ~4K token context window shared by prompt and response,
    /// so prompts are capped at roughly 2.5K tokens of thought text.
    private let thoughtCharacterBudget = 9_000

    /// Shortens each thought evenly so the whole list fits the on-device context window.
    private func fitted(_ thoughts: [String]) -> [String] {
        let total = thoughts.reduce(0) { $0 + $1.count }
        guard total > thoughtCharacterBudget, !thoughts.isEmpty else { return thoughts }
        let perThought = max(thoughtCharacterBudget / thoughts.count, 40)
        return thoughts.map { $0.count > perThought ? String($0.prefix(perThought)) + "…" : $0 }
    }

    /// Runs a model request, turning on-device model errors into readable messages.
    private func run<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch let error as LanguageModelSession.GenerationError {
            throw AIError.unavailable(Self.message(for: error))
        }
    }

    private static func message(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            return "There's too much text for Apple Intelligence to process at once."
        case .assetsUnavailable:
            return "Apple Intelligence is still getting ready. Try again in a few minutes."
        case .guardrailViolation, .refusal:
            return "Apple Intelligence declined to process this content."
        case .unsupportedLanguageOrLocale:
            return "Apple Intelligence doesn't support this language yet."
        case .rateLimited, .concurrentRequests:
            return "Apple Intelligence is busy. Try again in a moment."
        default:
            return "Apple Intelligence couldn't complete the request."
        }
    }

    func categorize(thoughts: [String]) async throws -> [CategoryResult] {
        let session = LanguageModelSession()
        let numbered = fitted(thoughts).enumerated()
            .map { "\($0.offset). \($0.element)" }
            .joined(separator: "\n")
        let prompt = """
        Group the following thoughts into meaningful categories. \
        Each thought belongs to exactly one category.

        Thoughts:
        \(numbered)
        """
        let response = try await run { try await session.respond(to: prompt, generating: CategorizationOutput.self) }
        return response.content.categories.map {
            CategoryResult(name: $0.name, thoughtIndices: $0.indices)
        }
    }

    func summarize(thoughts: [String], forCategory category: String?) async throws -> String {
        let session = LanguageModelSession()
        let context = category.map { " about \($0)" } ?? ""
        let prompt = "Summarize these thoughts\(context) in 2–3 sentences:\n\(fitted(thoughts).joined(separator: "\n"))"
        let response = try await run { try await session.respond(to: prompt) }
        return response.content
    }

    func dailySummary(thoughts: [String]) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        Create a concise daily summary highlighting key themes and insights in 3–5 sentences.

        Thoughts:
        \(fitted(thoughts).joined(separator: "\n"))
        """
        let response = try await run { try await session.respond(to: prompt) }
        return response.content
    }

    func cleanTranscript(_ text: String) async throws -> String {
        let session = LanguageModelSession()
        let prompt = "Clean up this voice-to-text transcription. Remove filler words (um, uh, like, you know, so), fix grammar, and make it clear and concise while preserving the original meaning. Return only the cleaned text with no explanation or preamble.\n\nTranscription: \(fitted([text])[0])"
        let response = try await run { try await session.respond(to: prompt) }
        return response.content
    }

    func generateTodos(thoughts: [String], categories: [String]) async throws -> [TodoResult] {
        let session = LanguageModelSession()
        let numbered = fitted(thoughts).enumerated()
            .map { "\($0.offset). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        Based on these thoughts and their categories, generate an actionable todo list.
        Categories: \(categories.joined(separator: ", "))
        Thoughts:
        \(numbered)
        Generate 3–8 specific, actionable tasks. Assign each an Eisenhower quadrant.
        """
        let response = try await run { try await session.respond(to: prompt, generating: TodoOutput.self) }
        return response.content.todos.map {
            TodoResult(title: $0.title, notes: $0.notes, quadrant: $0.quadrant)
        }
    }

    // MARK: - Image Playground

    /// Generates an illustration of the summary on device with Image Playground.
    func generateSummaryImage(summary: String) async throws -> Data? {
        do {
            let creator = try await ImageCreator()
            let preferred: [ImagePlaygroundStyle] = [.illustration, .animation, .sketch]
            guard let style = preferred.first(where: creator.availableStyles.contains) else {
                throw AIError.unavailable(Self.imageMessage("Image Playground's image styles are still downloading. Try again in a few minutes."))
            }
            let concept = ImagePlaygroundConcept.extracted(from: String(summary.prefix(1_000)), title: "My day")
            for try await image in creator.images(for: [concept], style: style, limit: 1) {
                return UIImage(cgImage: image.cgImage).pngData()
            }
            throw AIError.unavailable(Self.imageMessage("Image Playground didn't return a picture. Tap Regenerate Image to try again."))
        } catch let error as ImageCreator.Error {
            throw AIError.unavailable(Self.imageMessage(for: error))
        }
    }

    private static func imageMessage(_ detail: String) -> String {
        "Apple Intelligence makes images on your iPhone with Image Playground. \(detail)"
    }

    private static func imageMessage(for error: ImageCreator.Error) -> String {
        switch error {
        case .notSupported:
            return imageMessage("This iPhone doesn't support Image Playground. Choose OpenAI in Settings to get images.")
        case .unavailable:
            return imageMessage("It isn't ready yet. Turn on Apple Intelligence in Settings → Apple Intelligence & Siri, make sure the Image Playground app is installed, then try again.")
        case .unsupportedLanguage:
            return imageMessage("It doesn't support your iPhone's language or region yet.")
        case .backgroundCreationForbidden:
            return imageMessage("Keep the app open while the image is being created.")
        case .conceptsRequirePersonIdentity, .faceInImageTooSmall:
            return imageMessage("It can't draw this summary because it describes specific people.")
        case .creationCancelled:
            return imageMessage("Creating the image was cancelled. Tap Regenerate Image to try again.")
        default:
            return imageMessage("It couldn't create a picture for this summary. Tap Regenerate Image to try again.")
        }
    }
}
