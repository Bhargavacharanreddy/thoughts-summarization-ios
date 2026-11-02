import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = AppSettings()
    @State private var viewModel: ThoughtsViewModel?
    @State private var selectedTab = Tab.dump
    private let voiceCapture = VoiceCaptureRequest.shared

    enum Tab { case dump, categories, summary, history, tasks }

    var body: some View {
        Group {
            if let viewModel {
                TabView(selection: $selectedTab) {
                    DumpView()
                        .tabItem { Label("Dump", systemImage: "brain") }
                        .tag(Tab.dump)
                    CategoriesView()
                        .tabItem { Label("Categories", systemImage: "square.grid.2x2") }
                        .tag(Tab.categories)
                    DailySummaryView()
                        .tabItem { Label("Summary", systemImage: "doc.text") }
                        .tag(Tab.summary)
                    DailyHistoryView()
                        .tabItem { Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") }
                        .tag(Tab.history)
                    TasksView()
                        .tabItem { Label("Tasks", systemImage: "checklist") }
                        .tag(Tab.tasks)
                }
                .onChange(of: voiceCapture.isPending, initial: true) { _, pending in
                    if pending { selectedTab = .dump }
                }
                .environment(viewModel)
                .toolbarBackground(Color.spaceBg.opacity(0.95), for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .alert("Error", isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { viewModel.errorMessage = nil }
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }
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
        .modelContainer(for: [Thought.self, ThoughtCategory.self, DailySummary.self, TodoItem.self], inMemory: true)
}
