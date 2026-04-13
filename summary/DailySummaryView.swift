import SwiftUI

struct DailySummaryView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if viewModel.isGeneratingSummary {
                    generatingState(message: "Generating your summary…")
                } else if let summary = viewModel.dailySummary {
                    summaryContent(summary)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Today's Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.03, blue: 0.13),
                Color(red: 0.11, green: 0.05, blue: 0.21),
                Color(red: 0.05, green: 0.04, blue: 0.17)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Generating state

    private func generatingState(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(.purple)
            Text(message)
                .foregroundStyle(.white.opacity(0.55))
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .indigo.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 8) {
                    Text("Ready to summarize")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    Text(viewModel.todaysThoughts.isEmpty
                         ? "Add some thoughts in the Dump tab first."
                         : "You have \(viewModel.todaysThoughts.count) thought\(viewModel.todaysThoughts.count == 1 ? "" : "s") today. Tap below to summarize them.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                ActionButton(
                    label: "Generate Summary",
                    icon: "sparkles",
                    colors: [Color(red: 0.55, green: 0.22, blue: 0.92), Color(red: 0.32, green: 0.18, blue: 0.78)],
                    shadowColor: .purple,
                    disabled: viewModel.todaysThoughts.isEmpty
                ) {
                    Task { await viewModel.generateDailySummary() }
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Summary content

    private func summaryContent(_ summary: DailySummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Summary card ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {

                    // Date + thought count
                    HStack {
                        Label(summary.date.formatted(date: .abbreviated, time: .omitted),
                              systemImage: "calendar")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.purple.opacity(0.75))
                        Spacer()
                        Label("\(summary.thoughtCount) thoughts", systemImage: "brain")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    // Summary text — this is always visible
                    Text(summary.summaryText)
                        .font(.body)
                        .lineSpacing(6)
                        .foregroundStyle(.white.opacity(0.9))

                    // Category tags
                    if !viewModel.categories.isEmpty {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)
                        FlowTagLayout(viewModel.categories.map { $0.name })
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // ── Image section ───────────────────────────────────────────
                imageSectionView(summary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // ── Bottom actions ──────────────────────────────────────────
                VStack(spacing: 10) {
                    ActionButton(
                        label: "Regenerate Summary",
                        icon: "arrow.clockwise",
                        colors: [.white.opacity(0.12), .white.opacity(0.08)],
                        shadowColor: .clear,
                        disabled: false
                    ) {
                        Task { await viewModel.generateDailySummary() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Image section

    @ViewBuilder
    private func imageSectionView(_ summary: DailySummary) -> some View {
        if let data = summary.imageData, let uiImage = UIImage(data: data) {
            // Image is ready — show it with a regenerate option
            VStack(spacing: 10) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )

                Button {
                    Task { await viewModel.generateImageForCurrentSummary() }
                } label: {
                    Label("Regenerate Image", systemImage: "photo.badge.arrow.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .disabled(viewModel.isGeneratingImage)
            }

        } else if viewModel.isGeneratingImage {
            // Generating in progress
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 12) {
                        ProgressView().tint(.purple)
                        Text("Generating image…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("This may take 10–20 seconds")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.2))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.purple.opacity(0.2), lineWidth: 1)
                )

        } else {
            // No image yet — show generate button
            Button {
                Task { await viewModel.generateImageForCurrentSummary() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 22))
                            .foregroundStyle(.purple.opacity(0.8))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Generate Image")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("AI creates a visual of your day's thoughts")
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
                                .strokeBorder(.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Reusable action button

struct ActionButton: View {
    let label: String
    let icon: String
    let colors: [Color]
    let shadowColor: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label).fontWeight(.semibold)
            }
            .font(.system(size: 16))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: shadowColor.opacity(0.4), radius: 10, y: 4)
            .opacity(disabled ? 0.4 : 1)
        }
        .disabled(disabled)
    }
}

// MARK: - Flow Tag Layout

struct FlowTagLayout: View {
    let tags: [String]
    init(_ tags: [String]) { self.tags = tags }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.18))
                    .foregroundStyle(Color.purple.opacity(0.9))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.purple.opacity(0.3), lineWidth: 1))
            }
        }
    }
}

typealias FlowLayout = FlowTagLayout
