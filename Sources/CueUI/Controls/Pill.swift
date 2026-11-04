import SwiftUI

/// A small coloured badge with white text, like the display role badges
/// ("Stage", "Presenter view"), or a quiet status pill on dark glass.
public struct Pill: View {
    public enum Kind: Sendable {
        /// Solid colour fill, bold white text.
        case badge(Color)
        /// Dark translucent capsule with a status dot, e.g. "On stage".
        case status(dot: Color)
    }

    let title: String
    let kind: Kind

    public init(_ title: String, _ kind: Kind) {
        self.title = title
        self.kind = kind
    }

    public var body: some View {
        switch kind {
        case .badge(let color):
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        case .status(let dot):
            HStack(spacing: 7) {
                PulsingDot(dot)
                Text(title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white)
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background(Color(white: 0.04, opacity: 0.72), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

#Preview {
    VStack {
        Pill("Stage", .badge(CueTheme.destructive))
        Pill("On stage", .status(dot: CueTheme.destructive))
    }
    .padding(24).background(CueTheme.ground)
}
