import SwiftUI

/// One Bring!-style tile representing an outstanding exercise slot.
struct CycleTileView: View {
    let category: WorkoutCategory?
    var iconName: String = "dumbbell.fill"
    /// How many times this category still has to be done in the current cycle.
    var remaining: Int = 1

    private var color: Color { category?.color ?? .gray }
    private var name: String { category?.name ?? "Unknown" }

    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(name)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        // A single tile stands for every remaining rep of this category; the
        // badge counts down instead of the tiles multiplying across the grid.
        .overlay(alignment: .topTrailing) {
            if remaining > 1 {
                Text("\(remaining)")
                    .font(.headline.bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 34, minHeight: 34)
                    .background(Capsule().fill(.white.opacity(0.28)))
                    .padding(12)
                    .contentTransition(.numericText(countsDown: true))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .shadow(color: color.opacity(0.35), radius: 8, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(remaining > 1 ? "\(name), \(remaining) remaining" : name)
    }
}

/// Slight shrink on press for a tactile card feel.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Overlay shown for a moment when the last tile of a cycle is completed.
struct CelebrationView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("🎉")
                .font(.system(size: 64))
            Text("Cycle Complete!")
                .font(.title.bold())
            Text("Starting a fresh cycle…")
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
