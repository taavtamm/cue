import Foundation

/// When and how the glowing caret blinks. Pure logic so it can be tested
/// without a window. Values follow the spec: about 1.1 s per cycle, hold on,
/// ease out over ~150 ms, hold off, ease back in; solid while typing and for
/// 0.5 s after the last keystroke; hidden for a ranged selection; never
/// blinks with Reduce Motion on.
public enum CaretBlinkPolicy {
    public static let period: TimeInterval = 1.1
    public static let typingHold: TimeInterval = 0.5

    /// Keyframe times as fractions of `period`. 0.14 × 1.1 s ≈ 154 ms fades.
    public static let keyTimes: [Double] = [0, 0.38, 0.52, 0.86, 1]
    public static let keyValues: [Double] = [1, 1, 0, 0, 1]
    public static var fadeDuration: TimeInterval { (keyTimes[2] - keyTimes[1]) * period }

    public enum Presentation: Equatable, Sendable {
        case hidden, solid, blinking
    }

    public static func presentation(
        isFocused: Bool,
        hasRangedSelection: Bool,
        secondsSinceEdit: TimeInterval?,
        reduceMotion: Bool
    ) -> Presentation {
        guard isFocused, !hasRangedSelection else { return .hidden }
        if reduceMotion { return .solid }
        if let since = secondsSinceEdit, since < typingHold { return .solid }
        return .blinking
    }

    /// Caret opacity `seconds` into a blink cycle, with ease-in-out fades.
    /// Mirrors the Core Animation keyframes so tests can check the curve.
    public static func opacity(atCycleTime seconds: TimeInterval) -> Double {
        let t = seconds.truncatingRemainder(dividingBy: period) / period
        for index in 1..<keyTimes.count where t <= keyTimes[index] {
            let (t0, t1) = (keyTimes[index - 1], keyTimes[index])
            let (v0, v1) = (keyValues[index - 1], keyValues[index])
            let local = t1 > t0 ? (t - t0) / (t1 - t0) : 1
            return v0 + (v1 - v0) * easeInOut(local)
        }
        return keyValues[0]
    }

    /// Cubic ease-in-out, close to CAMediaTimingFunction(.easeInEaseOut).
    static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}
