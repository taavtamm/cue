import SwiftUI

/// One row of the animation timeline: a bar placed by fractions of the
/// timeline's span. Live embeds draw as a striped bar across the row.
public struct TimelineTrack: View {
    public enum Style: Sendable { case animation, loop, embed }

    let start: Double
    let width: Double
    let style: Style
    let tint: Color

    public init(start: Double, width: Double, style: Style = .animation, tint: Color = CueTheme.selection) {
        self.start = start
        self.width = width
        self.style = style
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.04))
                bar
                    .frame(width: max(4, geometry.size.width * width))
                    .offset(x: geometry.size.width * start)
            }
        }
        .frame(height: 18)
    }

    @ViewBuilder private var bar: some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        switch style {
        case .animation:
            shape.fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
        case .loop:
            shape.fill(tint.opacity(0.8))
        case .embed:
            shape.fill(ImagePaint(image: Self.stripes, scale: 1)).overlay(shape.fill(CueTheme.live.opacity(0.25)))
        }
    }

    /// Alternating cyan stripes, as in the design's "Web embed · live loop" row.
    private static let stripes: Image = {
        let image = NSImage(size: CGSize(width: 44, height: 18), flipped: false) { rect in
            NSColor(CueTheme.live).withAlphaComponent(0.55).setFill()
            NSRect(x: 0, y: 0, width: 22, height: rect.height).fill()
            NSColor(CueTheme.live).withAlphaComponent(0.25).setFill()
            NSRect(x: 22, y: 0, width: 22, height: rect.height).fill()
            return true
        }
        return Image(nsImage: image)
    }()
}

#Preview {
    VStack(spacing: 7) {
        TimelineTrack(start: 0, width: 0.14)
        TimelineTrack(start: 0.12, width: 0.09, style: .loop, tint: CueTheme.violet)
        TimelineTrack(start: 0, width: 1, style: .embed)
    }
    .frame(width: 500)
    .padding()
    .background(CueTheme.ground)
}
