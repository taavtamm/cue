import AppKit

/// Size and colour of the glowing caret. The glow recipe comes from the
/// spec: bright white core with faint pink and cyan ends, a warm glow
/// (cool white above, cream around, gold below) and a short capsule haze.
public struct CaretStyle: Sendable, Hashable {
    /// Width of the bar in points: 2 normally, 3 in the large Launcher field.
    public var barWidth: CGFloat
    /// The haze is this many bar-widths wide.
    public var hazeWidthFactor: CGFloat = 5
    /// How far the haze extends above and below the bar.
    public var hazeOverhang: CGFloat = 3
    public var hazeBlur: CGFloat = 3.5
    /// Scale for glow radii and offsets; the large caret glows wider.
    public var glowScale: CGFloat = 1

    public static let standard = CaretStyle(barWidth: 2)
    public static let large = CaretStyle(barWidth: 3, hazeOverhang: 5, hazeBlur: 5, glowScale: 1.7)
}

/// One soft shadow around the bar, matching a CSS box-shadow entry.
struct CaretGlow {
    let color: NSColor
    let opacity: Float
    let offsetY: CGFloat
    let blur: CGFloat

    /// 0 0 3 rgba(255,253,245,.95) · 0 0 7 rgba(255,238,190,.6) ·
    /// 0 -3 8 rgba(225,238,255,.3) · 0 4 9 rgba(255,214,120,.45)
    static let recipe: [CaretGlow] = [
        CaretGlow(color: rgb(255, 253, 245), opacity: 0.95, offsetY: 0, blur: 3),
        CaretGlow(color: rgb(255, 238, 190), opacity: 0.6, offsetY: 0, blur: 7),
        CaretGlow(color: rgb(225, 238, 255), opacity: 0.3, offsetY: -3, blur: 8),
        CaretGlow(color: rgb(255, 214, 120), opacity: 0.45, offsetY: 4, blur: 9),
    ]

    /// Haze gradient, top to bottom: cool white → warm white → gold.
    static let hazeColors: [(NSColor, CGFloat)] = [
        (rgb(228, 238, 255, 0.24), 0),
        (rgb(255, 250, 236, 0.30), 0.45),
        (rgb(255, 222, 150, 0.42), 1),
    ]

    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }
}
