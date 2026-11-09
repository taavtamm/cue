import CoreGraphics
import Foundation

/// A copy of an element that can stand on its own on any slide: the same
/// markup, absolutely positioned at `frame` on the design canvas, with a new
/// id. Used for duplicate, Option-drag and paste.
///
/// The copy keeps its classes, so it looks the same where the deck's styles
/// don't depend on where the element sits.
public enum ElementCopy {
    /// Placement properties the copy replaces.
    static let placementProperties: Set<String> = [
        "position", "left", "top", "right", "bottom", "width", "height", "translate", "margin", "inset",
    ]

    public static func portable(_ outerHTML: String, frame: CGRect, newID: String) -> String? {
        let text = Substring(outerHTML)
        guard text.hasPrefix("<"), let tag = RichTextSanitizer.Tag(parsing: text), !tag.isClosing else { return nil }
        var attributes = tag.attributeMap
        attributes["id"] = nil
        attributes["data-cue-id"] = nil
        // The raw value keeps its entities (`&quot;`), so split it with the
        // entity- and quote-aware scanner rather than on every `;`.
        let kept = StyleDeclarations(attributes.removeValue(forKey: "style") ?? "").sourceTexts
            .filter { !placementProperties.contains($0.property) }
            .map(\.text)
        let place = "position: absolute; left: \(ElementPlacement.px(frame.minX)); top: \(ElementPlacement.px(frame.minY)); "
            + "width: \(ElementPlacement.px(frame.width)); height: \(ElementPlacement.px(frame.height)); margin: 0"
        let style = ([place] + kept).joined(separator: "; ") + ";"
        attributes["data-cue-element"] = attributes["data-cue-element"] ?? "copy"
        var start = "<\(tag.name) id=\"\(newID)\""
        for name in attributes.keys.sorted() {
            let value = attributes[name] ?? ""
            start += value.isEmpty && name != "alt" ? " \(name)" : " \(name)=\"\(quoted(value))\""
        }
        start += " style=\"\(quoted(style))\">"
        return start + text[tag.end...]
    }

    private static func quoted(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "&quot;")
    }
}
