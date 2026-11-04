import CoreGraphics
import Foundation

/// Reads values out of an inline `style` attribute (as the parser decoded
/// it). For reading only; edits go through `StyleDeclarations` patches.
struct InlineStyle {
    private let values: [String: String]

    init(_ style: String) {
        var values: [String: String] = [:]
        for declaration in style.split(separator: ";") {
            let parts = declaration.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            values[name] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        self.values = values
    }

    subscript(_ property: String) -> String? { values[property] }

    /// `"128px"` → 128. Nil for other units or keywords.
    func pixels(_ property: String) -> CGFloat? {
        values[property].flatMap(Self.pixels)
    }

    /// The inline `translate:` offset, or (0, 0).
    var translate: (CGFloat, CGFloat) {
        guard let value = values["translate"], value != "none" else { return (0, 0) }
        let parts = value.split(separator: " ").compactMap { Self.pixels(String($0)) }
        return (parts.first ?? 0, parts.count > 1 ? parts[1] : 0)
    }

    static func pixels(_ text: String) -> CGFloat? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "0" { return 0 }
        guard trimmed.hasSuffix("px"), let number = Double(trimmed.dropLast(2)) else { return nil }
        return CGFloat(number)
    }
}
