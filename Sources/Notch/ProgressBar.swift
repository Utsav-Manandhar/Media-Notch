import SwiftUI

func clock(_ seconds: TimeInterval) -> String {
    String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
}

/// Glowing progress bar. Click or drag to seek; `onSeek` gets the new position in seconds.
struct ProgressBar: View {
    let position: TimeInterval
    let duration: TimeInterval
    let color: Color
    let onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?
    @State private var hovering = false

    var body: some View {
        let fraction = dragFraction ?? (duration > 0 ? position / duration : 0)
        HStack(spacing: 8) {
            Text(clock(fraction * duration))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * fraction)
                        .shadow(color: color.opacity(0.9), radius: 4)
                        .shadow(color: color.opacity(0.5), radius: 9)
                        // Not animated: a tick moves the bar under a point, and animating it would redraw every frame.
                }
                .frame(height: hovering || dragFraction != nil ? 7 : 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle()) // the whole 16 pt strip is clickable, not just the thin bar
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { dragFraction = min(1, max(0, $0.location.x / max(1, geo.size.width))) }
                    .onEnded { _ in
                        if let dragFraction { onSeek(dragFraction * duration) }
                        dragFraction = nil
                    })
                .onHover { hovering = $0 }
                .animation(.spring(duration: 0.25), value: hovering)
            }
            .frame(height: 16)
            Text(clock(duration))
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(clock(position)) of \(clock(duration))")
        .accessibilityAdjustableAction { direction in
            onSeek(min(duration, max(0, position + (direction == .increment ? 5 : -5))))
        }
    }
}

/// Accent-coloured glow that swells on hover and springs back when pressed.
struct GlowButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        GlowLabel(configuration: configuration, color: color)
    }

    private struct GlowLabel: View {
        let configuration: Configuration
        let color: Color
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(color)
                .shadow(color: color.opacity(hovering ? 1 : 0.7), radius: hovering ? 10 : 5)
                .shadow(color: color.opacity(hovering ? 0.6 : 0.3), radius: hovering ? 18 : 10)
                .scaleEffect(configuration.isPressed ? 0.8 : hovering ? 1.2 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: hovering)
                .onHover { hovering = $0 }
        }
    }
}
