import SwiftUI

struct DailySummaryView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isGeneratingSummary {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Generating your daily summary...")
                            .foregroundStyle(.secondary)
                    }
                } else if let summary = viewModel.dailySummary {
                    summaryContent(summary)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Today's Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.generateDailySummary() }
                    } label: {
                        Label("Generate", systemImage: "sparkles")
                    }
                    .disabled(viewModel.todaysThoughts.isEmpty || viewModel.isGeneratingSummary)
                }
            }
        }
    }

    private func summaryContent(_ summary: DailySummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label(summary.date.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("\(summary.thoughtCount) thoughts", systemImage: "brain")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(summary.summaryText)
                    .font(.body)
                    .lineSpacing(4)

                if !viewModel.categories.isEmpty {
                    Divider()
                    Text("Topics covered")
                        .font(.headline)
                    FlowLayout(viewModel.categories.map { $0.name })
                }

                Button {
                    Task { await viewModel.generateDailySummary() }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Summary Yet", systemImage: "doc.text")
        } description: {
            Text("Add your thoughts throughout the day, then generate a summary.")
        } actions: {
            Button("Generate Summary") {
                Task { await viewModel.generateDailySummary() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.todaysThoughts.isEmpty)
        }
    }
}

struct FlowLayout: View {
    let tags: [String]
    init(_ tags: [String]) { self.tags = tags }

    var body: some View {
        // Simple wrapping tag layout
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}
