import SwiftUI

struct CategoriesView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground()

                Group {
                    if viewModel.isCategorizingThoughts {
                        categorizingState
                    } else if viewModel.categories.isEmpty {
                        emptyState
                    } else {
                        categoryList
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.categorize() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.nebula)
                    }
                    .disabled(viewModel.todaysThoughts.isEmpty || viewModel.isCategorizingThoughts)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Categorizing State

    private var categorizingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(.nebula)
            Text("Categorizing thoughts…")
                .foregroundStyle(.white.opacity(0.55))
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(colors: [.nebula, .cosmicBlue],
                                   startPoint: .top, endPoint: .bottom)
                )
            Text("No Categories Yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Add thoughts and they'll be\nautomatically categorized after a few seconds.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            CosmicButton(label: "Categorize Now", icon: "wand.and.sparkles",
                         disabled: viewModel.todaysThoughts.isEmpty) {
                Task { await viewModel.categorize() }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Category List

    private var categoryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.categories) { category in
                    NavigationLink {
                        CategoryDetailView(category: category)
                    } label: {
                        CategoryRow(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: ThoughtCategory
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.nebula.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.nebula)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(category.thoughts.count) thought\(category.thoughts.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(14)
        .glassCard()
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}
