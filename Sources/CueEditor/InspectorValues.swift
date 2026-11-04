import CoreGraphics
import CueRender
import Foundation

/// What the Design inspector shows for a selected element, as display
/// strings, made from the page's computed style and the element's box on
/// the slide's design canvas.
public struct InspectorValues: Sendable, Equatable {
    public var fontFamily = ""
    public var fontWeight = ""
    /// Pixels, without the unit: "88".
    public var fontSize = ""
    /// A multiple of the font size, "1.04", or "Auto" for `normal`.
    public var lineHeight = ""
    /// Percent of the font size, "-2%".
    public var tracking = ""
    /// "#141414", or "#141414 · 80%" with alpha.
    public var color = ""
    /// The variable the colour comes from, e.g. "var(--ink)".
    public var colorVariable: String?
    public var x = "", y = "", width = "", height = ""
    /// "from deck stylesheet · .headline", "inline style", …
    public var source = ""

    public init() {}

    public init(inspection: ElementInspection, colorSource: StyleProvenance? = nil,
                fontSource: StyleProvenance? = nil) {
        let style = inspection.computedStyle
        let size = Self.pixels(style["font-size"]) ?? 0
        fontFamily = Self.firstFamily(style["font-family"] ?? "")
        fontWeight = Self.weightName(style["font-weight"] ?? "400")
        fontSize = Self.number(size)
        lineHeight = Self.lineHeight(style["line-height"], fontSize: size)
        tracking = Self.tracking(style["letter-spacing"], fontSize: size)
        color = Self.hex(style["color"] ?? "")
        if let declared = colorSource?.value, declared.contains("var(") { colorVariable = declared }
        let box = inspection.canvasFrame
        (x, y) = (Self.number(box.minX.rounded()), Self.number(box.minY.rounded()))
        (width, height) = (Self.number(box.width.rounded()), Self.number(box.height.rounded()))
        source = (fontSource ?? colorSource)?.summary ?? ""
    }

    // MARK: Formatting

    static func pixels(_ value: String?) -> Double? {
        guard let value, value.hasSuffix("px") else { return nil }
        return Double(value.dropLast(2))
    }

    /// Up to two decimals, no trailing zeros: 88, 1.04, -0.5.
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    static func firstFamily(_ list: String) -> String {
        let first = list.split(separator: ",").first.map(String.init) ?? list
        return first.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"'")))
    }

    static func weightName(_ weight: String) -> String {
        switch Int(weight) ?? 400 {
        case ..<150: "Thin"
        case ..<250: "Extra Light"
        case ..<350: "Light"
        case ..<450: "Regular"
        case ..<550: "Medium"
        case ..<650: "Semibold"
        case ..<750: "Bold"
        case ..<850: "Heavy"
        default: "Black"
        }
    }

    static func lineHeight(_ value: String?, fontSize: Double) -> String {
        guard let px = pixels(value), fontSize > 0 else { return value.map { $0 == "normal" ? "Auto" : $0 } ?? "Auto" }
        return number(px / fontSize)
    }

    static func tracking(_ value: String?, fontSize: Double) -> String {
        guard let px = pixels(value), fontSize > 0 else { return "0%" }
        return number((px / fontSize * 100).rounded()) + "%"
    }

    /// `rgb(20, 20, 20)` → `#141414`; `rgba(…, 0.8)` → `#141414 · 80%`.
    static func hex(_ color: String) -> String {
        let digits = color.split { !"0123456789.".contains($0) }.compactMap { Double($0) }
        guard color.hasPrefix("rgb"), digits.count >= 3 else { return color }
        let hex = digits.prefix(3).map { String(format: "%02X", Int($0.rounded())) }.joined()
        if digits.count >= 4, digits[3] < 1 { return "#\(hex) · \(Int((digits[3] * 100).rounded()))%" }
        return "#\(hex)"
    }
}
