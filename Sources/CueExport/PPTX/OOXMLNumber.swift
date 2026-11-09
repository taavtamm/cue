import Foundation

/// DrawingML integers from computed CSS. A page can produce any Double
/// (NaN, infinity, 1e300 px), and `Int(_:)` traps on those, so every
/// conversion in the PowerPoint writer goes through here.
enum OOXMLNumber {
    /// Rounded and clamped to Int32's range, which every DrawingML integer
    /// attribute accepts. NaN becomes 0.
    static func int(_ value: Double) -> Int {
        guard !value.isNaN else { return 0 }
        return Int(min(Double(Int32.max), max(Double(Int32.min), value.rounded())))
    }

    /// Rounded and clamped to `range`. NaN becomes the range's lower bound.
    static func int(_ value: Double, in range: ClosedRange<Int>) -> Int {
        guard !value.isNaN else { return range.lowerBound }
        return min(range.upperBound, max(range.lowerBound, int(value)))
    }

    /// Degrees (clockwise) as DrawingML's 60 000ths of a degree, 0 ..< 21 600 000.
    static func angle(degrees: Double) -> Int {
        guard degrees.isFinite else { return 0 }
        let turned = degrees.truncatingRemainder(dividingBy: 360)
        return int((turned < 0 ? turned + 360 : turned) * 60_000) % 21_600_000
    }

    /// A fraction (1 = 100 %) as DrawingML's 100 000ths.
    static func percent(_ fraction: Double) -> Int {
        int(fraction * 100_000)
    }
}
