import SwiftUI

/// Colour, shape and type tokens from the Cue design canvas. Every screen
/// reads from here instead of hard-coding values.
public enum CueTheme {
    // MARK: Ground and text
    public static let ground = Color(hex: 0x07070A)
    public static let poolPurple = Color(hex: 0x3A1F5C)
    public static let poolBlue = Color(hex: 0x0F3B5C)
    public static let poolWine = Color(hex: 0x4A1A2E)
    public static let text = Color(hex: 0xF5F5F7)
    /// Secondary text. 0.65 white on the ground keeps contrast above 4.5:1.
    public static let textSecondary = Color.white.opacity(0.65)
    public static let textTertiary = Color.white.opacity(0.6)

    // MARK: Accents
    public static let selection = Color(hex: 0x2F7BFF)
    public static let selectionText = Color(hex: 0x9ECBFF)
    public static let live = Color(hex: 0x38E1FF)
    public static let liveText = Color(hex: 0x7FE9FF)
    public static let success = Color(hex: 0x34C759)
    public static let successBright = Color(hex: 0x5DFFB0)
    public static let destructive = Color(hex: 0xFF453A)
    public static let destructiveText = Color(hex: 0xFF8A80)

    // MARK: Glass
    /// Window glass tint, about rgba(20,20,24,0.66).
    public static let glassTint = Color(red: 20 / 255, green: 20 / 255, blue: 24 / 255, opacity: 0.66)
    public static let glassBorder = Color.white.opacity(0.10)
    public static let glassHighlight = Color.white.opacity(0.14)
    /// Fill for controls sitting on glass (buttons, fields).
    public static let controlFill = Color.white.opacity(0.07)
    public static let controlFillHover = Color.white.opacity(0.14)
    public static let controlSelected = Color.white.opacity(0.16)
    public static let insetFill = Color.black.opacity(0.25)

    // MARK: Shape
    public static let windowRadius: CGFloat = 28
    public static let panelRadius: CGFloat = 20
    public static let controlRadius: CGFloat = 12
    public static let fieldRadius: CGFloat = 9

    // MARK: Siri glow
    /// The conic gradient stops, first and last equal so the ring loops.
    public static let siriGlowHex: [UInt32] = [
        0xFF5FA2, 0xB36BFF, 0x5B8CFF, 0x38E1FF, 0x5DFFB0, 0xFFD25E, 0xFF7A59, 0xFF5FA2,
    ]
    public static var siriGlowColors: [Color] { siriGlowHex.map { Color(hex: $0) } }
    /// Seconds per full turn of the glow.
    public static let siriGlowPeriod: TimeInterval = 5

    // MARK: Type
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    /// `Color(hex: 0x2F7BFF)`
    public init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
