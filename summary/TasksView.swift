import SwiftUI

struct TasksView: View {
    @Environment(ThoughtsViewModel.self) private var viewModel
    @State private var selectedTodo: TodoItem?
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground()

                if viewModel.todos.isEmpty && !viewModel.isGeneratingTodos {
                    emptyState
                } else {
                    matrixContent
                }
            }
            .navigationTitle("Mission Control")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if viewModel.isGeneratingTodos {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 6) {
                            ProgressView().tint(.nebula).scaleEffect(0.8)
                            Text("Generating…")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditSheet) {
            if let todo = selectedTodo {
                TodoEditSheet(todo: todo)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checklist.unchecked")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.nebula, .cosmicBlue],
                                                startPoint: .top, endPoint: .bottom))
            Text("No Tasks Yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Add thoughts and let AI categorize them.\nYour tasks will appear here automatically.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Matrix

    private var matrixContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Generating banner
                if viewModel.isGeneratingTodos {
                    HStack(spacing: 10) {
                        ProgressView().tint(.nebula)
                        Text("AI is generating your task list…")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.nebula.opacity(0.12))
                }

                // 2×2 Eisenhower grid
                let quadrants = EisenhowerQuadrant.allCases
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(quadrants) { quadrant in
                        QuadrantCard(
                            quadrant: quadrant,
                            todos: viewModel.todos.filter { $0.quadrant == quadrant },
                            onTap: { todo in
                                selectedTodo = todo
                                showEditSheet = true
                            },
                            onToggle: { todo in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.toggleTodoDone(todo)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
        }
    }
}

// MARK: - Quadrant Card

struct QuadrantCard: View {
    let quadrant: EisenhowerQuadrant
    let todos: [TodoItem]
    let onTap: (TodoItem) -> Void
    let onToggle: (TodoItem) -> Void

    private var activeTodos: [TodoItem] { todos.filter { !$0.isDone } }
    private var doneTodos: [TodoItem] { todos.filter { $0.isDone } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: quadrant.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(quadrant.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(quadrant.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(quadrant.subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if !todos.isEmpty {
                    Text("\(activeTodos.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(quadrant.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(quadrant.color.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Rectangle()
                .fill(quadrant.color.opacity(0.25))
                .frame(height: 1)
                .padding(.horizontal, 8)

            // Todo rows
            if todos.isEmpty {
                Text("No tasks")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(activeTodos) { todo in
                        TodoRow(todo: todo, accentColor: quadrant.color,
                                onTap: { onTap(todo) }, onToggle: { onToggle(todo) })
                    }
                    if !doneTodos.isEmpty {
                        ForEach(doneTodos.prefix(2)) { todo in
                            TodoRow(todo: todo, accentColor: .gray,
                                    onTap: { onTap(todo) }, onToggle: { onToggle(todo) })
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(quadrant.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: quadrant.color.opacity(0.1), radius: 8)
        )
    }
}

// MARK: - Todo Row

struct TodoRow: View {
    let todo: TodoItem
    let accentColor: Color
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(todo.isDone ? accentColor : .white.opacity(0.3))
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                Text(todo.title)
                    .font(.caption)
                    .foregroundStyle(todo.isDone ? .white.opacity(0.3) : .white.opacity(0.85))
                    .strikethrough(todo.isDone, color: .white.opacity(0.3))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
