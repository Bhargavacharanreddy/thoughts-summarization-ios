import SwiftUI

struct CategoryDetailView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel
    let category: ThoughtCategory
    @State private var isLoadingSummary = false

    var body: some View {
        ZStack {
            SpaceBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // AI Summary card
                    if let summary = category.summary {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI Summary", systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.nebula)
                                .textCase(.uppercase)
                                .tracking(0.8)
                            Text(summary)
                                .font(.body)
                                .lineSpacing(5)
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        .padding(16)
                        .glassCard()
                    }

                    // Thoughts list
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Thoughts (\(category.thoughts.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .textCase(.uppercase)
                            .tracking(1)

                        VStack(spacing: 8) {
                            ForEach(category.thoughts) { thought in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: thought.inputType == .voice ? "waveform" : "text.bubble")
                                        .font(.system(size: 13))
                                        .foregroundStyle(thought.inputType == .voice ? .nebula : .auroraTeal)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(thought.content)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.85))
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(thought.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.white.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
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
                        ProgressView().tint(.nebula)
                    } else {
                        Label("Summarize", systemImage: "sparkles")
                            .foregroundStyle(.nebula)
                    }
                }
                .disabled(isLoadingSummary || category.thoughts.isEmpty)
            }
        }
    }
}
