import SwiftUI

// MARK: - Space Dialog

/// A space-themed replacement for system alerts: a glowing glass card over a dimmed backdrop.
struct SpaceDialogButton: Identifiable {
    enum Role { case primary, destructive, cancel }

    let id = UUID()
    let title: String
    var role: Role = .primary
    var action: () -> Void = {}

    static func cancel(_ title: String = "Cancel") -> SpaceDialogButton {
        SpaceDialogButton(title: title, role: .cancel)
    }
}

private struct SpaceDialogCard: View {
    let icon: String
    let tint: Color
    let title: String
    let message: String
    let buttons: [SpaceDialogButton]
    let dismiss: () -> Void

    @State private var glow = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.55), .clear], center: .center, startRadius: 4, endRadius: 46))
                    .frame(width: 92, height: 92)
                    .scaleEffect(glow ? 1.12 : 0.92)
                    .opacity(glow ? 1 : 0.6)
                Circle()
                    .fill(LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: tint.opacity(0.7), radius: 14)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: glow)
            }
            .padding(.top, 4)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(buttons) { button in
                    Button {
                        dismiss()
                        button.action()
                    } label: {
                        Text(button.title)
                            .font(.body.weight(button.role == .cancel ? .medium : .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(button.role == .cancel ? .white.opacity(0.75) : .white)
                            .background(background(for: button.role))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: 330)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.spaceBg.opacity(0.92))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(colors: [tint.opacity(0.8), .white.opacity(0.08), Color.nebula.opacity(0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
        )
        .shadow(color: tint.opacity(0.35), radius: 30)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    @ViewBuilder
    private func background(for role: SpaceDialogButton.Role) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        switch role {
        case .primary:
            shape.fill(LinearGradient(colors: [Color.nebula, Color.cosmicBlue], startPoint: .leading, endPoint: .trailing))
        case .destructive:
            shape.fill(LinearGradient(colors: [Color(red: 0.86, green: 0.23, blue: 0.3), Color(red: 0.55, green: 0.12, blue: 0.35)],
                                      startPoint: .leading, endPoint: .trailing))
        case .cancel:
            shape.fill(.white.opacity(0.07)).overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
    }
}

private struct SpaceDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let icon: String
    let tint: Color
    let title: String
    let message: String
    let buttons: [SpaceDialogButton]

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                if isPresented {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            // Tapping outside only dismisses when there's a safe way out.
                            if buttons.contains(where: { $0.role == .cancel }) || buttons.count == 1 { close() }
                        }
                    SpaceDialogCard(icon: icon, tint: tint, title: title, message: message,
                                    buttons: buttons, dismiss: close)
                        .padding(.horizontal, 24)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.78), value: isPresented)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPresented) { _, new in new }
    }

    private func close() { isPresented = false }
}

extension View {
    /// Shows a space-themed dialog. Buttons dismiss it before running their action.
    func spaceDialog(
        isPresented: Binding<Bool>,
        icon: String,
        tint: Color = .nebula,
        title: String,
        message: String,
        buttons: [SpaceDialogButton] = [SpaceDialogButton(title: "OK")]
    ) -> some View {
        modifier(SpaceDialogModifier(isPresented: isPresented, icon: icon, tint: tint,
                                     title: title, message: message, buttons: buttons))
    }
}
