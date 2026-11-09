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
        paragraph.contents.map { piece in
            switch piece {
            case .text(let string): HTMLText.text(string.trimmingCharacters(in: .newlines))
            case .element(let child): run(child, styles: styles)
            }
        }.joined()
    }

    private static func run(_ child: XNode, styles: ODPTextStyles) -> String {
        switch child.name {
        case "span":
            let style = styles[child["style-name"]]?.text ?? ""
            return "<span style=\"\(HTMLText.attribute(style))\">\(HTMLText.text(text(child)))</span>"
        case "line-break": return "<br>"
        case "s": return spaces(child)
        case "tab": return "\t"
        default: return HTMLText.text(text(child))
        }
    }

    /// `text:s` stands for `text:c` spaces (a count from the file, kept sane).
    private static func spaces(_ node: XNode) -> String {
        String(repeating: " ", count: min(max(node.int("c") ?? 1, 0), 1000))
    }

    /// The node's text with its children's text where they sit.
    private static func text(_ node: XNode) -> String {
        node.contents.map { piece in
            switch piece {
            case .text(let string): string
            case .element(let child):
                switch child.name {
                case "line-break": "\n"
                case "s": spaces(child)
                case "tab": "\t"
                default: text(child)
                }
            }
        }.joined()
    }
}
