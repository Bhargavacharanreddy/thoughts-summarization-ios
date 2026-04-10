import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = AppSettings()
    @State private var viewModel: ThoughtsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                TabView {
                    DumpView()
                        .tabItem { Label("Dump", systemImage: "brain") }
                    CategoriesView()
                        .tabItem { Label("Categories", systemImage: "square.grid.2x2") }
                    DailySummaryView()
                        .tabItem { Label("Summary", systemImage: "doc.text") }
                }
                .environment(viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ThoughtsViewModel(modelContext: modelContext, settings: settings)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Thought.self, ThoughtCategory.self, DailySummary.self], inMemory: true)
}
