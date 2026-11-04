import Foundation

/// Cleans formatted text from the page before it goes into the deck: only
/// simple inline formatting survives, and nothing that can run code.
///
/// Kept: `b strong i em u s sub sup span font br p div`, and `a` with an
/// `http(s):` or `mailto:` link. Dropped with their content: `script`,
/// `style` and comments. Any other tag is dropped but its text kept.
///
/// The deck's own formatting survives an edit: `class`, `title`, `lang`,
/// `dir`, `data-*`, a font's `color`/`face`/`size`, and `style` minus any
/// declaration that could load or run something. Event handlers are always
/// dropped, and so are Cue's temporary `data-cue-*` markers, which must
/// never reach the file. Attributes keep their original order.
public enum RichTextSanitizer {
    static let allowedTags: Set<String> = [
        "b", "strong", "i", "em", "u", "s", "sub", "sup", "span", "font", "br", "p", "div", "a",
    ]
    static let keptAttributes: Set<String> = ["class", "title", "lang", "dir"]
    static let fontAttributes: Set<String> = ["color", "face", "size"]
    static let droppedWithContent: Set<String> = ["script", "style", "template", "iframe", "object", "noscript"]

    public static func sanitize(_ html: String) -> String {
        var output = ""
        var rest = Substring(html)
        while let open = rest.firstIndex(of: "<") {
            output += rest[..<open]
            rest = rest[open...]
            if rest.hasPrefix("<!--") {
                rest = rest.range(of: "-->").map { rest[$0.upperBound...] } ?? ""
                continue
            }
            guard let tag = Tag(parsing: rest) else { // A lone "<": keep it as text.
                output += "&lt;"
                rest = rest.dropFirst()
                continue
            }
            rest = rest[tag.end...]
            if droppedWithContent.contains(tag.name), !tag.isClosing {
                rest = rest.range(of: "</\(tag.name)", options: .caseInsensitive)
                    .map { rest[$0.upperBound...].drop { $0 != ">" }.dropFirst() } ?? ""
                continue
            }
            guard allowedTags.contains(tag.name) else { continue }
            output += tag.isClosing ? "</\(tag.name)>" : "<\(tag.name)\(safeAttributes(of: tag))>"
        }
        return output + rest
    }

    private static func safeAttributes(of tag: Tag) -> String {
        tag.attributes.compactMap { name, value -> String? in
            guard let kept = safeValue(name, value, on: tag.name) else { return nil }
            return " \(name)=\"\(kept.replacingOccurrences(of: "\"", with: "&quot;"))\""
        }.joined()
    }

    private static func safeValue(_ name: String, _ value: String, on tag: String) -> String? {
        if name.hasPrefix("on") || name.hasPrefix("data-cue-") { return nil }
        if keptAttributes.contains(name) || name.hasPrefix("data-") { return value }
        if tag == "font", fontAttributes.contains(name) { return value }
        if name == "style" { return safeStyle(value) }
        if tag == "a", name == "href" {
            let lower = value.lowercased().trimmingCharacters(in: .whitespaces)
            return ["http://", "https://", "mailto:"].contains(where: lower.hasPrefix) ? value : nil
        }
        return nil
    }

    /// Inline style with only declarations that can't load or run anything.
    static func safeStyle(_ style: String) -> String? {
        let unsafe = ["url(", "expression", "javascript:", "@import", "behavior", "-moz-binding"]
        let kept = style.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { declaration in
            let lower = declaration.lowercased()
            return declaration.contains(":") && !unsafe.contains(where: lower.contains)
        }
        return kept.isEmpty ? nil : kept.joined(separator: "; ") + ";"
    }

    /// One `<tag …>` or `</tag>`, with its attributes.
    struct Tag {
        let name: String
        let isClosing: Bool
        /// In the order they were written.
        let attributes: [(name: String, value: String)]
        /// The same attributes by name.
        var attributeMap: [String: String] {
            Dictionary(attributes.map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first })
        }
        /// Just past the `>`.
        let end: Substring.Index

        init?(parsing text: Substring) {
            var index = text.index(after: text.startIndex)
            let closing = index < text.endIndex && text[index] == "/"
            if closing { index = text.index(after: index) }
            let nameStart = index
            while index < text.endIndex, text[index].isLetter || text[index].isNumber { index = text.index(after: index) }
            guard index > nameStart else { return nil }
            name = text[nameStart..<index].lowercased()
            isClosing = closing
            var attributes: [(name: String, value: String)] = []
            var quote: Character?
            var attributeStart = index
            while index < text.endIndex {
                let character = text[index]
                if let open = quote {
                    if character == open { quote = nil }
                } else if character == "\"" || character == "'" {
                    quote = character
                } else if character == ">" {
                    break
                }
                index = text.index(after: index)
            }
            guard index < text.endIndex else { return nil }
            Self.readAttributes(String(text[attributeStart..<index]), into: &attributes)
            attributeStart = index
            self.attributes = attributes
            end = text.index(after: index)
        }

        private static func readAttributes(_ text: String, into attributes: inout [(name: String, value: String)]) {
            let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let name = Range(match.range(at: 1), in: text).map({ text[$0].lowercased() }) else { continue }
                let value = (2...4).lazy.compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }.first
                if !attributes.contains(where: { $0.name == name }) { attributes.append((name, value ?? "")) }
            }
        }
    }
}
