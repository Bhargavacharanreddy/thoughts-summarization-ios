import SwiftData
import Foundation

enum InputType: String, Codable {
    case voice
    case text
}

enum EisenhowerQuadrant: String, Codable, CaseIterable, Identifiable {
    case urgentImportant       = "urgentImportant"
    case notUrgentImportant    = "notUrgentImportant"
    case urgentNotImportant    = "urgentNotImportant"
    case notUrgentNotImportant = "notUrgentNotImportant"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urgentImportant:       return "Do First"
        case .notUrgentImportant:    return "Schedule"
        case .urgentNotImportant:    return "Delegate"
        case .notUrgentNotImportant: return "Eliminate"
        }
    }

    var subtitle: String {
        switch self {
        case .urgentImportant:       return "Urgent & Important"
        case .notUrgentImportant:    return "Not Urgent, Important"
        case .urgentNotImportant:    return "Urgent, Not Important"
        case .notUrgentNotImportant: return "Not Urgent, Not Important"
        }
    }
}

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var notes: String
    var quadrant: EisenhowerQuadrant
    var isDone: Bool
    var createdAt: Date

    init(title: String, notes: String = "", quadrant: EisenhowerQuadrant) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.quadrant = quadrant
        self.isDone = false
        self.createdAt = Date()
    }
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
    var imageData: Data?

    init(date: Date, summaryText: String, thoughtCount: Int) {
        self.id = UUID()
        self.date = date
        self.summaryText = summaryText
        self.thoughtCount = thoughtCount
    }
}
