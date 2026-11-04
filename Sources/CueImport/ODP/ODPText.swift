import Foundation

/// Character styles from `office:automatic-styles`, by style name.
struct ODPTextStyles {
    private var styles: [String: CSSStyle] = [:]

    init(_ automatic: XNode?) {
        for style in automatic?.children("style") ?? [] {
            guard let name = style["name"], let text = style.child("text-properties") else { continue }
            var css = CSSStyle()
            if let size = text["font-size"], size.hasSuffix("pt") { css.set("font-size", CueImport.css(ODPLength.pixels(size))) }
            css.set("color", text["color"])
            if text["font-weight"] == "bold" { css.set("font-weight", "700") }
            if text["font-style"] == "italic" { css.set("font-style", "italic") }
            css.set("font-family", text["font-family"].map { "\"\($0)\", \(FontCatalog.sans)" })
            styles[name] = css
        }
    }

    subscript(_ name: String?) -> CSSStyle? { name.flatMap { styles[$0] } }
}

/// Paragraphs, list items and spans as HTML or plain text.
enum ODPText {
    static func html(_ container: XNode, styles: ODPTextStyles) -> String {
        paragraphs(in: container).map { paragraph in
            let style = styles[paragraph["style-name"]]?.text ?? ""
            let inner = runs(paragraph, styles: styles)
            return "<p style=\"font-size: 24px; \(HTMLText.attribute(style))\">\(inner.isEmpty ? "<br>" : inner)</p>"
        }.joined()
    }

    static func plain(_ container: XNode) -> String {
        paragraphs(in: container).map(text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func paragraphs(in node: XNode) -> [XNode] {
        node.descendants.filter { $0.name == "p" || $0.name == "h" }
    }

    private static func runs(_ paragraph: XNode, styles: ODPTextStyles) -> String {
        var out = HTMLText.text(paragraph.text.trimmingCharacters(in: .newlines))
        for child in paragraph.children {
            switch child.name {
            case "span":
                let style = styles[child["style-name"]]?.text ?? ""
                out += "<span style=\"\(HTMLText.attribute(style))\">\(HTMLText.text(text(child)))</span>"
            case "line-break": out += "<br>"
            case "s": out += String(repeating: " ", count: child.int("c") ?? 1)
            case "tab": out += "\t"
            default: out += HTMLText.text(text(child))
            }
        }
        return out
    }

    private static func text(_ node: XNode) -> String {
        node.text + node.children.map { $0.name == "line-break" ? "\n" : text($0) }.joined()
    }
}
