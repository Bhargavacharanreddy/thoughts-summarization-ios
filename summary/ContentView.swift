import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settings = AppSettings()
    @State private var viewModel: ThoughtsViewModel?
    @State private var selectedTab = Tab.dump
    @State private var showError = false
    @State private var shownError = ""
    @State private var shownErrorTitle = ""
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
                .onChange(of: viewModel.errorMessage) { _, message in
                    if let message {
                        shownError = message
                        shownErrorTitle = viewModel.errorTitle ?? "Something Went Wrong"
                        showError = true
                    }
                }
                .onChange(of: showError) { _, shown in
                    if !shown {
                        viewModel.errorMessage = nil
                        viewModel.errorTitle = nil
                    }
                }
                .spaceDialog(
                    isPresented: $showError,
                    icon: "exclamationmark.triangle.fill",
                    tint: .starGold,
                    title: shownErrorTitle,
                    message: shownError,
                    buttons: [SpaceDialogButton(title: "Got It")]
                )
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
