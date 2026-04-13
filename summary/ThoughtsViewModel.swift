import Foundation
import SwiftData

@MainActor
@Observable
class ThoughtsViewModel {
    var todaysThoughts: [Thought] = []
    var categories: [ThoughtCategory] = []
    var dailySummary: DailySummary?
    var historicalSummaries: [DailySummary] = []

    var isCategorizingThoughts = false
    var isGeneratingSummary = false
    var isGeneratingImage = false
    var isCleaningTranscript = false
    var errorMessage: String?

    private let modelContext: ModelContext
    let settings: AppSettings
    private var autoCategorizationTask: Task<Void, Never>?

    init(modelContext: ModelContext, settings: AppSettings) {
        self.modelContext = modelContext
        self.settings = settings
        loadTodaysData()
    }

    // MARK: - Adding Thoughts

    func addThought(_ content: String, inputType: InputType) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let thought = Thought(content: trimmed, inputType: inputType)
        modelContext.insert(thought)
        todaysThoughts.insert(thought, at: 0)
        try? modelContext.save()
        scheduleAutoCategoriziation()
    }

    func deleteThought(_ thought: Thought) {
        todaysThoughts.removeAll { $0.id == thought.id }
        modelContext.delete(thought)
        try? modelContext.save()
    }

    /// Cleans up a voice transcript using the active AI service (or Whisper if OpenAI),
    /// then saves it as a thought. Shows `isCleaningTranscript` during the process.
    func cleanAndAddVoiceThought(transcript: String, audioFileURL: URL?) async {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if let url = audioFileURL { try? FileManager.default.removeItem(at: url) }
            return
        }

        isCleaningTranscript = true
        defer { isCleaningTranscript = false }

        var finalTranscript = trimmed

        if let service = settings.makeAIService() {
            if settings.selectedProvider == .openAI,
               let url = audioFileURL,
               let openAI = service as? OpenAIService {
                // Whisper gives better quality for OpenAI users
                if let whisperText = try? await openAI.transcribeAudio(fileURL: url),
                   !whisperText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalTranscript = whisperText
                }
            } else {
                // AI cleanup: removes filler words and fixes grammar
                if let cleaned = try? await service.cleanTranscript(trimmed),
                   !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalTranscript = cleaned
                }
            }
        }

        // Clean up the audio file regardless
        if let url = audioFileURL { try? FileManager.default.removeItem(at: url) }

        addThought(finalTranscript, inputType: .voice)
    }

    // MARK: - AI Actions

    func categorize() async {
        guard let service = settings.makeAIService() else {
            errorMessage = AIError.noAPIKey.errorDescription
            return
        }
        guard !todaysThoughts.isEmpty else { return }

        isCategorizingThoughts = true
        defer { isCategorizingThoughts = false }

        let contents = todaysThoughts.map { $0.content }
        do {
            let results = try await service.categorize(thoughts: contents)
            updateCategories(from: results)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateDailySummary() async {
        guard let service = settings.makeAIService() else {
            errorMessage = AIError.noAPIKey.errorDescription
            return
        }
        guard !todaysThoughts.isEmpty else { return }

        isGeneratingSummary = true
        defer { isGeneratingSummary = false }

        let contents = todaysThoughts.map { $0.content }
        do {
            let text = try await service.dailySummary(thoughts: contents)
            let today = Calendar.current.startOfDay(for: Date())
            if let existing = dailySummary { modelContext.delete(existing) }
            let summary = DailySummary(date: today, summaryText: text, thoughtCount: contents.count)
            modelContext.insert(summary)
            dailySummary = summary
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Generate (or regenerate) the image for today's summary.
    func generateImageForCurrentSummary() async {
        guard let summary = dailySummary else { return }
        await generateImage(for: summary)
    }

    /// Generate (or regenerate) the image for any summary — today or historical.
    func generateImage(for summary: DailySummary) async {
        guard let service = settings.makeAIService() else {
            errorMessage = AIError.noAPIKey.errorDescription
            return
        }
        isGeneratingImage = true
        defer { isGeneratingImage = false }

        do {
            if let imageData = try await service.generateSummaryImage(summary: summary.summaryText) {
                summary.imageData = imageData
                try? modelContext.save()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func summarizeCategory(_ category: ThoughtCategory) async -> String? {
        guard let service = settings.makeAIService() else {
            errorMessage = AIError.noAPIKey.errorDescription
            return nil
        }
        let contents = category.thoughts.map { $0.content }
        guard !contents.isEmpty else { return nil }
        do {
            let text = try await service.summarize(thoughts: contents, forCategory: category.name)
            category.summary = text
            try? modelContext.save()
            return text
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - History

    func loadHistoricalSummaries() {
        let today = Calendar.current.startOfDay(for: Date())
        let desc = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date < today },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        historicalSummaries = (try? modelContext.fetch(desc)) ?? []
    }

    func loadThoughts(for date: Date) -> [Thought] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let desc = FetchDescriptor<Thought>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(desc)) ?? []
    }

    // MARK: - Private

    private func loadTodaysData() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let thoughtDesc = FetchDescriptor<Thought>(
            predicate: #Predicate { $0.timestamp >= today && $0.timestamp < tomorrow },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        todaysThoughts = (try? modelContext.fetch(thoughtDesc)) ?? []

        let catDesc = FetchDescriptor<ThoughtCategory>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )
        categories = (try? modelContext.fetch(catDesc)) ?? []

        let sumDesc = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )
        dailySummary = try? modelContext.fetch(sumDesc).first
    }

    private func updateCategories(from results: [CategoryResult]) {
        for cat in categories { modelContext.delete(cat) }
        categories = []

        for result in results {
            let cat = ThoughtCategory(name: result.name)
            for index in result.thoughtIndices {
                guard index < todaysThoughts.count else { continue }
                let thought = todaysThoughts[index]
                thought.category = cat
                cat.thoughts.append(thought)
            }
            modelContext.insert(cat)
            categories.append(cat)
        }
        try? modelContext.save()
    }

    private func scheduleAutoCategoriziation() {
        autoCategorizationTask?.cancel()
        autoCategorizationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            await self.categorize()
        }
    }
}
