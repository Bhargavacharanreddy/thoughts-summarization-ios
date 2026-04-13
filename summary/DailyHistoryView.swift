import SwiftUI

struct DailyHistoryView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground()
                Group {
                    if viewModel.historicalSummaries.isEmpty {
                        emptyState
                    } else {
                        historyList
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.loadHistoricalSummaries() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.nebula.opacity(0.55), .indigo.opacity(0.3)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Text("No past summaries yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.45))
            Text("Your daily summaries will appear here")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.28))
            Spacer()
        }
    }

    // MARK: - History List

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.historicalSummaries) { summary in
                    NavigationLink {
                        HistoryDetailView(summary: summary)
                            .environment(viewModel)
                    } label: {
                        HistorySummaryCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - History Summary Card

struct HistorySummaryCard: View {
    let summary: DailySummary
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            // Thumbnail image or placeholder
            Group {
                if let data = summary.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.nebula.opacity(0.12)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 28))
                            .foregroundStyle(.nebula.opacity(0.4))
                    }
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.nebula.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(summary.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Label("\(summary.thoughtCount) thoughts", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.trailing, 12)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

// MARK: - History Detail View

struct HistoryDetailView: View {
    let summary: DailySummary
    @Environment(ThoughtsViewModel.self) private var viewModel
    @State private var thoughts: [Thought] = []
    @State private var zoomedImage: UIImage?
    @State private var showImageZoom = false

    var body: some View {
        ZStack {
            SpaceBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Image section ───────────────────────────────────────
                    historyImageSection

                    // ── Meta ────────────────────────────────────────────────
                    HStack {
                        Label(summary.date.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Label("\(summary.thoughtCount) thoughts", systemImage: "brain")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    // ── Summary ─────────────────────────────────────────────
                    Text(summary.summaryText)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundStyle(.white.opacity(0.88))

                    // ── Individual thoughts ─────────────────────────────────
                    if !thoughts.isEmpty {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)

                        Text("Thoughts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.45))
                            .textCase(.uppercase)
                            .tracking(1)

                        ForEach(thoughts) { thought in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(thought.inputType == .voice ? Color.nebula.opacity(0.5) : Color.cyan.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(thought.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(summary.date.formatted(.dateTime.month(.wide).day().year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            thoughts = viewModel.loadThoughts(for: summary.date)
        }
        .fullScreenCover(isPresented: $showImageZoom) {
            if let img = zoomedImage {
                ImageZoomViewer(image: img)
            }
        }
    }

    @ViewBuilder
    private var historyImageSection: some View {
        if let data = summary.imageData, let uiImage = UIImage(data: data) {
            // Image exists
            VStack(spacing: 10) {
                Button {
                    zoomedImage = uiImage
                    showImageZoom = true
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.generateImage(for: summary) }
                } label: {
                    Label("Regenerate Image", systemImage: "photo.badge.arrow.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .disabled(viewModel.isGeneratingImage)
            }

        } else if viewModel.isGeneratingImage {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
                .frame(height: 180)
                .overlay(
                    VStack(spacing: 12) {
                        ProgressView().tint(.nebula)
                        Text("Generating image…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.nebula.opacity(0.2), lineWidth: 1)
                )
        } else {
            // No image — show generate button
            Button {
                Task { await viewModel.generateImage(for: summary) }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 22))
                            .foregroundStyle(.nebula.opacity(0.8))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Generate Image")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("AI creates a visual of this day's thoughts")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white.opacity(0.055))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(.nebula.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}
