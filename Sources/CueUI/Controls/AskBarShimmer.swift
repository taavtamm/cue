import SwiftUI

/// A soft light sweeping across the Ask bar while the agent edits the slide.
struct AskBarShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let period: TimeInterval = 1.4

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { timeline in
                GeometryReader { geometry in
                    let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
                    LinearGradient(colors: [.clear, .white.opacity(0.14), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geometry.size.width * 0.35)
                        .offset(x: (geometry.size.width * 1.35) * phase - geometry.size.width * 0.35)
                }
            }
            .clipShape(Capsule())
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
