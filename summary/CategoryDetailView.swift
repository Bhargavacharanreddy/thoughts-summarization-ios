import SwiftUI

struct CategoryDetailView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel
    let category: ThoughtCategory
    @State private var isLoadingSummary = false

    var body: some View {
        List {
            if let summary = category.summary {
                Section("Summary") {
                    Text(summary)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Thoughts (\(category.thoughts.count))") {
                ForEach(category.thoughts) { thought in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(thought.content)
                        HStack(spacing: 6) {
                            Image(systemName: thought.inputType == .voice ? "waveform" : "text.bubble")
                                .font(.caption2)
                            Text(thought.timestamp, style: .time)
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        isLoadingSummary = true
                        await viewModel.summarizeCategory(category)
                        isLoadingSummary = false
                    }
                } label: {
                    if isLoadingSummary {
                        ProgressView()
                    } else {
                        Label("Summarize", systemImage: "sparkles")
                    }
                }
                .disabled(isLoadingSummary || category.thoughts.isEmpty)
            }
        }
    }
}
