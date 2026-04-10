import Foundation
import SwiftData

@Observable
class ThoughtsViewModel {
    var todaysThoughts: [Thought] = []
    var categories: [ThoughtCategory] = []
    var dailySummary: DailySummary?

    var isCategorizingThoughts = false
    var isGeneratingSummary = false
    var errorMessage: String?

    private let modelContext: ModelContext
    let settings: AppSettings

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
    }

    func deleteThought(_ thought: Thought) {
        todaysThoughts.removeAll { $0.id == thought.id }
        modelContext.delete(thought)
        try? modelContext.save()
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
}
