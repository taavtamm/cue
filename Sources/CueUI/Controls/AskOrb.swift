import SwiftUI

/// The small Siri-coloured orb at the start of the Ask bar. Breathes gently
/// (scale 1 ↔ 1.08 over 3.2 s); holds still with Reduce Motion.
public struct AskOrb: View {
    var diameter: CGFloat = 26
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    public init(diameter: CGFloat = 26) { self.diameter = diameter }

    public var body: some View {
        Circle()
            .fill(AngularGradient(colors: CueTheme.siriGlowColors, center: .center))
            .overlay(Circle().fill(RadialGradient(
                colors: [.white.opacity(0.85), .white.opacity(0)], center: .init(x: 0.38, y: 0.35),
                startRadius: 0, endRadius: diameter * 0.45
            )))
            .blur(radius: 0.6)
            .frame(width: diameter, height: diameter)
            .scaleEffect(breathing ? 1.08 : 1)
            .opacity(breathing ? 1 : 0.85)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathing = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview { AskOrb().padding(24).background(CueTheme.ground) }
