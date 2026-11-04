import SwiftUI

/// "3 / 12 | Build 2 of 3 ●●○" — where the show is, in a quiet capsule.
public struct PositionCounter: View {
    let slide: Int
    let slideCount: Int
    /// Current build (0 = slide only) and number of builds on this slide.
    let build: Int
    let buildCount: Int

    public init(slide: Int, slideCount: Int, build: Int = 0, buildCount: Int = 0) {
        self.slide = slide
        self.slideCount = slideCount
        self.build = build
        self.buildCount = buildCount
    }

    public var body: some View {
        HStack(spacing: 10) {
            Text("\(slide + 1) / \(slideCount)")
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
            if buildCount > 0 {
                Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 16)
                Text("Build \(build) of \(buildCount)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.white.opacity(0.72))
                dots
            }
        }
        .foregroundStyle(CueTheme.text)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(CueTheme.controlFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var dots: some View {
        HStack(spacing: 4) {
            ForEach(0..<buildCount, id: \.self) { index in
                Circle()
                    .fill(index < build ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var accessibilityText: String {
        let base = "Slide \(slide + 1) of \(slideCount)"
        return buildCount > 0 ? base + ", build \(build) of \(buildCount)" : base
    }
}

#Preview {
    VStack(spacing: 12) {
        PositionCounter(slide: 2, slideCount: 12, build: 2, buildCount: 3)
        PositionCounter(slide: 0, slideCount: 12)
    }
    .padding(24)
    .background(CueTheme.ground)
}
