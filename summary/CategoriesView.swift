import SwiftUI

struct CategoriesView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isCategorizingThoughts {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Categorizing thoughts...")
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.categories.isEmpty {
                    emptyState
                } else {
                    categoryList
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.categorize() }
                    } label: {
                        Label("Categorize", systemImage: "sparkles")
                    }
                    .disabled(viewModel.todaysThoughts.isEmpty || viewModel.isCategorizingThoughts)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Categories Yet", systemImage: "square.grid.2x2")
        } description: {
            Text("Add thoughts first, then tap the sparkles button to categorize them.")
        } actions: {
            Button("Categorize Now") {
                Task { await viewModel.categorize() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.todaysThoughts.isEmpty)
        }
    }

    private var categoryList: some View {
        List(viewModel.categories) { category in
            NavigationLink {
                CategoryDetailView(category: category)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.headline)
                        Text("\(category.thoughts.count) thought\(category.thoughts.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }
}
