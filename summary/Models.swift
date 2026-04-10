import SwiftData
import Foundation

enum InputType: String, Codable {
    case voice
    case text
}

@Model
final class Thought {
    var id: UUID
    var content: String
    var timestamp: Date
    var inputType: InputType
    var category: ThoughtCategory?

    init(content: String, inputType: InputType) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.inputType = inputType
    }
}

@Model
final class ThoughtCategory {
    var id: UUID
    var name: String
    var date: Date
    var summary: String?
    @Relationship(deleteRule: .nullify, inverse: \Thought.category) var thoughts: [Thought]

    init(name: String, date: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.thoughts = []
    }
}

@Model
final class DailySummary {
    var id: UUID
    var date: Date
    var summaryText: String
    var thoughtCount: Int

    init(date: Date, summaryText: String, thoughtCount: Int) {
        self.id = UUID()
        self.date = date
        self.summaryText = summaryText
        self.thoughtCount = thoughtCount
    }
}
