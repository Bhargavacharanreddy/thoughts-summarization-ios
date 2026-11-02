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
            .safeAreaInset(edge: .top, spacing: 0) { missionHeader }
            .toolbar(.hidden, for: .navigationBar)
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
                .foregroundStyle(LinearGradient(colors: [.purple, .blue],
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

    // MARK: - Mission Header

    private var activeCount: Int { viewModel.todos.filter { !$0.isDone }.count }
    private var doneCount: Int { viewModel.todos.count - activeCount }
    private var progress: Double {
        viewModel.todos.isEmpty ? 0 : Double(doneCount) / Double(viewModel.todos.count)
    }

    private var missionHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [Color.auroraTeal, Color.nebula, Color.starGold, Color.auroraTeal], center: .center),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                Image(systemName: viewModel.isGeneratingTodos ? "sparkles" : "paperplane.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: viewModel.isGeneratingTodos)
                    .shadow(color: Color.nebula, radius: 8)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("Mission Control")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Color(red: 0.8, green: 0.7, blue: 1.0)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: Color.nebula.opacity(0.6), radius: 10)
                Group {
                    if viewModel.isGeneratingTodos {
                        Text("AI is plotting your tasks…")
                    } else if viewModel.todos.isEmpty {
                        Text("Awaiting your first thoughts")
                    } else {
                        Text("\(activeCount) active · \(doneCount) done · \(Int(progress * 100))% complete")
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
                .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Matrix

    private var matrixContent: some View {
        // Rows share the available height, so the bottom row never runs under the tab bar.
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                card(.urgentImportant)
                card(.notUrgentImportant)
            }
            HStack(spacing: 12) {
                card(.urgentNotImportant)
                card(.notUrgentNotImportant)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func card(_ quadrant: EisenhowerQuadrant) -> some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            HStack(spacing: 8) {
                Image(systemName: quadrant.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [quadrant.color, quadrant.color.opacity(0.5)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: quadrant.color.opacity(0.7), radius: 6)
                    )
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(quadrant.color.opacity(0.75))
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
                VStack(spacing: 6) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 18))
                        .foregroundStyle(quadrant.color.opacity(0.45))
                    Text("All clear")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(activeTodos) { todo in
                            TodoRow(todo: todo, accentColor: quadrant.color,
                                    onTap: { onTap(todo) }, onToggle: { onToggle(todo) })
                        }
                        if !doneTodos.isEmpty {
                            ForEach(doneTodos) { todo in
                                TodoRow(todo: todo, accentColor: .gray,
                                        onTap: { onTap(todo) }, onToggle: { onToggle(todo) })
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(colors: [quadrant.color.opacity(0.16), Color.white.opacity(0.03)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(colors: [quadrant.color.opacity(0.7), quadrant.color.opacity(0.1)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
                .shadow(color: quadrant.color.opacity(0.18), radius: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
