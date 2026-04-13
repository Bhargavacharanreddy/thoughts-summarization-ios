import SwiftUI

// MARK: - Space Color Palette

extension Color {
    static let spaceBg       = Color(red: 0.031, green: 0.043, blue: 0.082)  // #080B15
    static let nebula        = Color(red: 0.482, green: 0.184, blue: 0.745)  // #7B2FBE
    static let cosmicBlue    = Color(red: 0.118, green: 0.227, blue: 0.541)  // #1E3A8A
    static let starGold      = Color(red: 0.961, green: 0.620, blue: 0.043)  // #F59E0B
    static let auroraTeal    = Color(red: 0.051, green: 0.580, blue: 0.533)  // #0D9488
    static let stardust      = Color.white.opacity(0.75)
}

// MARK: - Quadrant colors

extension EisenhowerQuadrant {
    var color: Color {
        switch self {
        case .urgentImportant:       return Color(red: 0.86, green: 0.23, blue: 0.23)  // red
        case .notUrgentImportant:    return Color.cosmicBlue
        case .urgentNotImportant:    return Color.starGold
        case .notUrgentNotImportant: return Color(red: 0.35, green: 0.37, blue: 0.42) // gray
        }
    }
    var icon: String {
        switch self {
        case .urgentImportant:       return "flame.fill"
        case .notUrgentImportant:    return "calendar.badge.clock"
        case .urgentNotImportant:    return "person.wave.2.fill"
        case .notUrgentNotImportant: return "trash.fill"
        }
    }
}

// MARK: - Space Background

struct SpaceBackground: View {
    var body: some View {
        ZStack {
            Color.spaceBg.ignoresSafeArea()
            StarFieldView().ignoresSafeArea()
        }
    }
}

// MARK: - Animated Star Field (Canvas-based, 30fps)

struct StarFieldView: View {
    private struct Star: Identifiable {
        let id = UUID()
        let x: CGFloat      // 0..1 normalized
        let y: CGFloat
        let size: CGFloat
        let phase: Double   // random 0..2π for twinkling offset
        let speed: Double   // twinkling speed multiplier
    }

    private let stars: [Star] = (0..<120).map { _ in
        Star(x: CGFloat.random(in: 0...1),
             y: CGFloat.random(in: 0...1),
             size: CGFloat.random(in: 0.8...2.5),
             phase: Double.random(in: 0...(2 * .pi)),
             speed: Double.random(in: 0.4...1.2))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/20)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for star in stars {
                    let opacity = 0.25 + 0.65 * (0.5 + 0.5 * sin(t * star.speed + star.phase))
                    let rect = CGRect(
                        x: star.x * size.width - star.size / 2,
                        y: star.y * size.height - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    context.opacity = opacity
                    context.fill(Circle().path(in: rect), with: .color(.white))
                }
            }
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var glow: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(glow.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: glow.opacity(0.18), radius: 12, y: 4)
            )
    }
}

extension View {
    func glassCard(glow: Color = .nebula, radius: CGFloat = 18) -> some View {
        modifier(GlassCardModifier(glow: glow, radius: radius))
    }
}

// MARK: - Cosmic Button

struct CosmicButton: View {
    let label: String
    let icon: String
    var colors: [Color] = [.nebula, Color(red: 0.32, green: 0.18, blue: 0.78)]
    var disabled: Bool = false
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
            .background(LinearGradient(colors: disabled ? [.gray.opacity(0.3)] : colors,
                                       startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: (disabled ? Color.clear : colors.first ?? .nebula).opacity(0.45),
                    radius: 12, y: 4)
        }
        .disabled(disabled)
    }
}
