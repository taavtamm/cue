import SwiftUI

/// A status dot that breathes (opacity 0.35 ↔ 1, 1.6 s). Used for "On
/// stage", "Playing live" and the Ask bar status. Breathes only while its
/// window is active, so a background window costs nothing; holds still with
/// Reduce Motion.
public struct PulsingDot: View {
    let color: Color
    var diameter: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState
    @State private var dim = false

    public init(_ color: Color, diameter: CGFloat = 8) {
        self.color = color
        self.diameter = diameter
    }

    private var animates: Bool { !reduceMotion && activeState != .inactive }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .opacity(dim ? 0.35 : 1)
            .onAppear { breathe(animates) }
            .onChange(of: animates) { breathe(animates) }
            .accessibilityHidden(true)
    }

    /// A new, non-repeating animation replaces the repeating one, so it stops.
    private func breathe(_ on: Bool) {
        if on {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { dim = false }
        }
    }
}

#Preview {
    HStack { PulsingDot(CueTheme.destructive); PulsingDot(CueTheme.live); PulsingDot(CueTheme.successBright) }
        .padding(24).background(CueTheme.ground)
}
