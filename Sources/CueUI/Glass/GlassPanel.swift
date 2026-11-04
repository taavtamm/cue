import SwiftUI

/// Cue's glass surface: system Liquid Glass tinted toward near-black, with
/// a 1 px hairline border and a soft top highlight. Use `.window` for
/// window-level chrome and `.panel` for panels inside a window.
public struct GlassPanelStyle: Sendable, Equatable {
    public var cornerRadius: CGFloat
    public var tint: Color

    public static let window = GlassPanelStyle(cornerRadius: CueTheme.windowRadius, tint: CueTheme.glassTint)
    public static let panel = GlassPanelStyle(cornerRadius: CueTheme.panelRadius, tint: CueTheme.glassTint)
}

extension View {
    /// Places the view on Cue glass. The system provides the blur and
    /// refraction; Cue only adds tint, border and highlight.
    public func cueGlass(_ style: GlassPanelStyle = .panel) -> some View {
        modifier(CueGlassModifier(style: style))
    }
}

struct CueGlassModifier: ViewModifier {
    let style: GlassPanelStyle

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        content
            .glassEffect(.regular.tint(style.tint), in: shape)
            .overlay(GlassEdge(shape: shape))
    }
}

/// The hairline border plus a top inner highlight, drawn over glass.
struct GlassEdge<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        ZStack {
            shape.strokeBorder(CueTheme.glassBorder, lineWidth: 1)
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [CueTheme.glassHighlight, .clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.08)
                    ),
                    lineWidth: 1
                )
        }
        .allowsHitTesting(false)
    }
}

/// A panel inside a glass window: quieter than glass, no blur of its own.
public struct InsetPanel<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: CueTheme.panelRadius, style: .continuous)
        content
            .background(Color.white.opacity(0.045), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }
}

#Preview {
    ZStack {
        CueBackground()
        VStack(spacing: 24) {
            Text("Window glass").padding(40).cueGlass(.window)
            InsetPanel { Text("Inset panel").padding(24) }
        }
        .foregroundStyle(CueTheme.text)
    }
    .frame(width: 520, height: 420)
}
