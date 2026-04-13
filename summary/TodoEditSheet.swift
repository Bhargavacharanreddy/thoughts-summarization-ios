import SwiftUI

struct TodoEditSheet: View {
    let todo: TodoItem
    @Environment(ThoughtsViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var quadrant: EisenhowerQuadrant = .notUrgentNotImportant
    @State private var isDone: Bool = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            label("Task")
                            TextField("What needs to be done?", text: $title, axis: .vertical)
                                .lineLimit(2...4)
                                .foregroundStyle(.white)
                                .tint(.nebula)
                                .padding(14)
                                .glassCard()
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            label("Notes")
                            TextField("Additional context (optional)", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .foregroundStyle(.white)
                                .tint(.nebula)
                                .padding(14)
                                .glassCard()
                        }

                        // Quadrant picker
                        VStack(alignment: .leading, spacing: 8) {
                            label("Priority Quadrant")
                            VStack(spacing: 8) {
                                ForEach(EisenhowerQuadrant.allCases) { q in
                                    Button {
                                        withAnimation(.snappy) { quadrant = q }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: q.icon)
                                                .font(.system(size: 16))
                                                .foregroundStyle(q.color)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(q.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.white.opacity(0.9))
                                                Text(q.subtitle)
                                                    .font(.caption2)
                                                    .foregroundStyle(.white.opacity(0.4))
                                            }
                                            Spacer()
                                            if quadrant == q {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(q.color)
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(quadrant == q ? q.color.opacity(0.15) : Color.white.opacity(0.04))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .strokeBorder(quadrant == q ? q.color.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Done toggle
                        Toggle(isOn: $isDone) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.auroraTeal)
                                Text("Mark as Done")
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                        .tint(.auroraTeal)
                        .padding(14)
                        .glassCard()

                        // Delete
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(.red.opacity(0.8))
                                .glassCard(glow: .red)
                        }
                        .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm,
                                            titleVisibility: .visible) {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteTodo(todo)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.updateTodo(todo, title: title, notes: notes, quadrant: quadrant)
                        if isDone != todo.isDone { viewModel.toggleTodoDone(todo) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.nebula)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            title = todo.title
            notes = todo.notes
            quadrant = todo.quadrant
            isDone = todo.isDone
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.4))
            .textCase(.uppercase)
            .tracking(1)
    }
}
