import Foundation

/// Turns what the user typed into an inspector field into a CSS value.
/// Returns nil when the input can't be a value for that field, so nothing
/// is written.
public enum StyleInput {
    public enum Field: Sendable {
        case fontSize, lineHeight, tracking, color, width, height
    }

    /// The CSS property each field edits.
    public static func property(for field: Field) -> String {
        switch field {
        case .fontSize: "font-size"
        case .lineHeight: "line-height"
        case .tracking: "letter-spacing"
        case .color: "color"
        case .width: "width"
        case .height: "height"
        }
    }

    public static func cssValue(_ input: String, for field: Field) -> String? {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        switch field {
        case .fontSize, .width, .height:
            if let number = Double(text) { return InspectorValues.number(number) + "px" }
            return hasUnit(text) ? text : nil
        case .lineHeight:
            if text.lowercased() == "auto" { return "normal" }
            return Double(text) != nil || hasUnit(text) ? text : nil
        case .tracking:
            // The inspector shows tracking as % of the font size, which is em × 100.
            let percent = text.hasSuffix("%") ? String(text.dropLast()) : text
            guard let number = Double(percent) else { return hasUnit(text) ? text : nil }
            return InspectorValues.number(number / 100) + "em"
        case .color:
            let hexDigits = text.hasPrefix("#") ? text.dropFirst() : Substring(text)
            if [3, 4, 6, 8].contains(hexDigits.count), hexDigits.allSatisfy(\.isHexDigit) { return "#" + hexDigits }
            return text.hasPrefix("rgb") || text.hasPrefix("hsl") || text.hasPrefix("var(") ? text : nil
        }
    }

    private static func hasUnit(_ text: String) -> Bool {
        let units = ["px", "em", "rem", "%", "vw", "vh", "pt"]
        return units.contains { text.hasSuffix($0) && Double(text.dropLast($0.count)) != nil }
    }
}
