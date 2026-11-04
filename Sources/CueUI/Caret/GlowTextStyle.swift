import AppKit

/// Presets for Cue's text inputs. Every text input in the app uses one.
public struct GlowTextStyle: Sendable, Equatable {
    public var fontSize: CGFloat
    public var fontWeight: NSFont.Weight = .regular
    public var isMonospaced = false
    public var isSingleLine = true
    public var caret: CaretStyle = .standard
    public var kerning: CGFloat = 0

    /// Inspector values, rename, find, URL fields.
    public static let field = GlowTextStyle(fontSize: 13)
    public static let compact = GlowTextStyle(fontSize: 12)
    /// The Ask bar under the slide.
    public static let ask = GlowTextStyle(fontSize: 16)
    /// Speaker notes and other multi-line text.
    public static let notes = GlowTextStyle(fontSize: 13.5, isSingleLine: false)
    /// The big Launcher field: 44 pt with the 3 pt caret.
    public static let launcher = GlowTextStyle(fontSize: 44, caret: .large, kerning: -0.6)
    public static let code = GlowTextStyle(fontSize: 12, isMonospaced: true, isSingleLine: false)

    var font: NSFont {
        isMonospaced
            ? .monospacedSystemFont(ofSize: fontSize, weight: fontWeight)
            : .systemFont(ofSize: fontSize, weight: fontWeight)
    }

    var lineHeight: CGFloat { ceil(font.ascender - font.descender + font.leading) }
}
