import SwiftUI
import SwiftData

@main
struct summaryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Thought.self, ThoughtCategory.self, DailySummary.self])
    }
}
