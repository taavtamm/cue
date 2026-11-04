import Foundation

/// Top-level `selector { declarations }` rules in a stylesheet's text, with
/// their positions. Only what Cue's override block needs: at-rules and
/// nested blocks are skipped, comments and strings are respected.
struct CSSRules {
    struct Rule {
        let selector: String
        /// From the selector's first character to the closing `}`.
        let range: Range<Int>
        /// Between `{` and `}`.
        let body: Range<Int>
    }

    let rules: [Rule]

    /// Offsets are UTF-16, relative to the start of `css`.
    init(_ css: String) {
        let units = Array(css.utf16)
        var rules: [Rule] = []
        var index = 0
        var selectorStart: Int?
        var depth = 0
        var bodyStart = 0
        var isAtRule = false
        func text(_ range: Range<Int>) -> String { String(decoding: units[range], as: UTF16.self) }
        while index < units.count {
            let unit = units[index]
            if let end = Self.endOfCommentOrString(units, at: index) {
                index = end
                continue
            }
            if depth == 0, selectorStart == nil, !Self.isSpace(unit) {
                selectorStart = index
                isAtRule = unit == 0x40
            }
            if unit == 0x7B {
                if depth == 0 { bodyStart = index + 1 }
                depth += 1
            } else if unit == 0x7D, depth > 0 {
                depth -= 1
                if depth == 0, let start = selectorStart {
                    if !isAtRule {
                        let selector = text(start..<(bodyStart - 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                        rules.append(Rule(selector: selector, range: start..<(index + 1), body: bodyStart..<index))
                    }
                    selectorStart = nil
                }
            } else if unit == 0x3B, depth == 0 {
                selectorStart = nil // `@import …;` and similar
            }
            index += 1
        }
        self.rules = rules
    }

    /// Where a `/* comment */` or quoted string starting at `index` ends.
    private static func endOfCommentOrString(_ units: [UTF16.CodeUnit], at index: Int) -> Int? {
        let unit = units[index]
        if unit == 0x2F, units[safe: index + 1] == 0x2A {
            var end = index + 2
            while end + 1 < units.count, !(units[end] == 0x2A && units[end + 1] == 0x2F) { end += 1 }
            return end + 2
        }
        guard unit == 0x22 || unit == 0x27 else { return nil }
        var end = index + 1
        while end < units.count, units[end] != unit { end += units[end] == 0x5C ? 2 : 1 }
        return end + 1
    }

    func rule(for selector: String) -> Rule? {
        rules.last { $0.selector == selector.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func isSpace(_ unit: UTF16.CodeUnit) -> Bool {
        unit == 0x20 || unit == 0x0A || unit == 0x0D || unit == 0x09
    }
}
