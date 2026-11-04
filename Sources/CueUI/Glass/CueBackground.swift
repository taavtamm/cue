import SwiftUI

/// The near-black ground with three large, soft colour pools
/// (purple top-left, blue top-right, wine bottom) from the designs.
public struct CueBackground: View {
    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                CueTheme.ground
                pool(CueTheme.poolPurple, at: UnitPoint(x: 0.14, y: 0.12), size: size, scale: 0.65)
                pool(CueTheme.poolBlue, at: UnitPoint(x: 0.9, y: 0.2), size: size, scale: 0.58)
                pool(CueTheme.poolWine, at: UnitPoint(x: 0.62, y: 1.05), size: size, scale: 0.7)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func pool(_ color: Color, at center: UnitPoint, size: CGSize, scale: CGFloat) -> some View {
        EllipticalGradient(
            colors: [color, color.opacity(0)],
            center: center,
            startRadiusFraction: 0,
            endRadiusFraction: scale
        )
    }
}

#Preview { CueBackground().frame(width: 800, height: 500) }
