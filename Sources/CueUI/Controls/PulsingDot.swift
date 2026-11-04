import SwiftUI

/// A status dot that breathes (opacity 0.35 ↔ 1, 1.6 s). Used for "On
/// stage", "Playing live" and the embed status. Holds still with Reduce Motion.
public struct PulsingDot: View {
    let color: Color
    var diameter: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    public init(_ color: Color, diameter: CGFloat = 8) {
        self.color = color
        self.diameter = diameter
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .opacity(dim && !reduceMotion ? 0.35 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack { PulsingDot(CueTheme.destructive); PulsingDot(CueTheme.live); PulsingDot(CueTheme.successBright) }
        .padding(24).background(CueTheme.ground)
}
