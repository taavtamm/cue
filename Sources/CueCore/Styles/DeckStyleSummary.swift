import Foundation

/// A deck's design system in a few kilobytes, for Claude: theme variables,
/// fonts, colours, the classes most used and what they style, where the CSS
/// lives. Stylesheets can be hundreds of kilobytes, so this summarises and
/// never dumps them.
public struct DeckStyleSummary: Sendable, Codable, Equatable {
    public struct Sheet: Sendable, Codable, Equatable {
        public let source: String
        public let kilobytes: Int
        public let rules: Int
    }

    public struct ClassUse: Sendable, Codable, Equatable {
        public let name: String
        public let elements: Int
        /// The `.name` rule's declarations, shortened, when the deck has one.
        public let declarations: String?
    }

    public struct Count: Sendable, Codable, Equatable {
        public let value: String
        public let uses: Int
    }

    public let stylesheets: [Sheet]
    /// Custom properties set on `:root`, `html` or `body`.
    public let variables: [String: String]
    public let fontFamilies: [Count]
    public let colors: [Count]
    public let fontFaces: [String]
    public let linkedStylesheets: [String]
    public let classes: [ClassUse]
    /// Elements styled inline (`style="…"`), which many generated decks use instead of classes.
    public let inlineStyledElements: Int
    /// Cue's own override block, as it is now.
    public let overrides: String?

    public init(_ document: DeckDocument) {
        let blocks = StyleBlocks(document)
        stylesheets = blocks.sheets.map { Sheet(source: $0.source, kilobytes: $0.css.utf8.count / 1024, rules: CSSRules($0.css).rules.count) }
        let allCSS = blocks.sheets.map(\.css).joined(separator: "\n")
        let rules = blocks.sheets.flatMap { sheet in CSSRules(sheet.css).rules.map { (sheet.units, $0) } }
        var variables: [String: String] = [:]
        for (units, rule) in rules where [":root", "html", "body"].contains(where: rule.selector.contains) {
            let body = Self.text(units, rule.body)
            for match in Self.matches(#"(--[A-Za-z0-9_-]+)\s*:\s*([^;}]+)"#, in: body) where variables.count < 120 {
                variables[match[1]] = variables[match[1]] ?? Self.clip(match[2].trimmingCharacters(in: .whitespaces), 120)
            }
        }
        self.variables = variables
        let inline = document.sourceMap.elements.compactMap { $0.attributes["style"] }
        let styleText = allCSS + "\n" + inline.joined(separator: ";\n")
        fontFamilies = Self.top(Self.matches(#"font-family\s*:\s*([^;}{]+)"#, in: styleText).map {
            $0[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "&quot;", with: "\"")
        }, 12)
        colors = Self.top(Self.matches(#"(#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|hsla?\([^)]*\))"#, in: styleText).map { $0[1].lowercased() }, 20)
        fontFaces = Array(Set(Self.matches(#"@font-face\s*\{[^}]*font-family\s*:\s*([^;}]+)"#, in: allCSS).map {
            $0[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
        })).sorted()
        linkedStylesheets = document.sourceMap.elements.filter { $0.tag == "link" && ($0.attributes["rel"] ?? "").contains("stylesheet") }
            .compactMap { $0.attributes["href"] }
        var classCounts: [String: Int] = [:]
        for element in document.sourceMap.elements {
            for name in (element.attributes["class"] ?? "").split(whereSeparator: \.isWhitespace) { classCounts[String(name), default: 0] += 1 }
        }
        classes = classCounts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(20).map { name, count in
            let rule = rules.last { $0.1.selector == ".\(name)" }
            return ClassUse(name: name, elements: count, declarations: rule.map { Self.clip(Self.text($0.0, $0.1.body), 240) })
        }
        inlineStyledElements = inline.count
        overrides = blocks.sheets.first { $0.source == "cue-overrides" }.map { Self.clip($0.css, 4_000) }
    }

    /// Rules whose selector mentions `selector`, or whose text contains `query`.
    public static func rules(in document: DeckDocument, selector: String?, query: String?, limit: Int = 30) -> [StyleRule] {
        let blocks = StyleBlocks(document)
        var found: [StyleRule] = []
        for sheet in blocks.sheets {
            for rule in CSSRules(sheet.css).rules {
                let body = text(sheet.units, rule.body)
                let selectorHit = selector.map { rule.selector.localizedCaseInsensitiveContains($0) } ?? true
                let queryHit = query.map { rule.selector.localizedCaseInsensitiveContains($0) || body.localizedCaseInsensitiveContains($0) } ?? true
                if selectorHit && queryHit {
                    found.append(StyleRule(source: sheet.source, selector: clip(rule.selector, 200), declarations: clip(body, 500)))
                    if found.count == limit { return found }
                }
            }
        }
        return found
    }

    // MARK: Helpers

    static func text(_ units: [UTF16.CodeUnit], _ range: Range<Int>) -> String {
        String(decoding: units[range], as: UTF16.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Long values (base64 fonts and images) cut, so a summary stays small.
    static func clip(_ text: String, _ limit: Int) -> String {
        let shortened = text.replacingOccurrences(of: #"base64,[A-Za-z0-9+/=]{200,}"#, with: "base64,…", options: .regularExpression)
        return shortened.count <= limit ? shortened : String(shortened.prefix(limit)) + "…"
    }

    static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: source.length)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : source.substring(with: match.range(at: $0)) }
        }
    }

    static func top(_ values: [String], _ limit: Int) -> [Count] {
        var counts: [String: Int] = [:]
        for value in values { counts[value, default: 0] += 1 }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(limit).map { Count(value: clip($0.key, 160), uses: $0.value) }
    }
}

/// One CSS rule as Claude sees it.
public struct StyleRule: Sendable, Codable, Equatable {
    public let source: String
    public let selector: String
    public let declarations: String
}

/// The `<style>` blocks written in a deck, labelled by id or position.
struct StyleBlocks {
    struct Sheet {
        let source: String
        let css: String
        let units: [UTF16.CodeUnit]
    }
    let sheets: [Sheet]

    init(_ document: DeckDocument) {
        let source = document.source as NSString
        var index = 0
        sheets = document.sourceMap.elements.compactMap { element in
            guard element.tag == "style", let inner = element.innerRange else { return nil }
            index += 1
            let css = source.substring(with: NSRange(location: inner.start, length: inner.length))
            return Sheet(source: element.attributes["id"] ?? "style \(index)", css: css, units: Array(css.utf16))
        }
    }
}
