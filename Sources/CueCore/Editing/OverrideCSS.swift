import Foundation

/// Checks and merges CSS for Cue's `<style id="cue-overrides">` block.
enum OverrideCSS {
    /// Rough but safe: balanced braces, nothing that ends the style block,
    /// loads remote CSS, or runs code.
    static func validate(_ css: String) throws {
        let lower = css.lowercased()
        if lower.contains("</style") { throw EditError.unsupported("CSS can't contain </style>") }
        for banned in ["javascript:", "expression(", "behavior:", "-moz-binding", "vbscript:"] where lower.contains(banned) {
            throw EditError.unsupported("CSS can't contain “\(banned)”")
        }
        if lower.range(of: #"@import\s+(url\()?\s*["']?(https?:)?//"#, options: .regularExpression) != nil {
            throw EditError.unsupported("CSS can't @import a remote stylesheet; add fonts with add_font")
        }
        var depth = 0
        for character in strippingCommentsAndStrings(css) {
            if character == "{" { depth += 1 }
            if character == "}" { depth -= 1; if depth < 0 { break } }
        }
        guard depth == 0 else { throw EditError.unsupported("CSS braces don't balance") }
    }

    /// `incoming`'s rules replace rules with the same selector in `current`
    /// (in place, so the order stays), new ones are added at the end, and
    /// at-rules (@media, @font-face, @keyframes) are added as written.
    static func merge(_ incoming: String, into current: String) -> String {
        let newRules = CSSRules(incoming)
        let newUnits = Array(incoming.utf16)
        func newText(_ range: Range<Int>) -> String { String(decoding: newUnits[range], as: UTF16.self) }
        var result = current
        var appended: [String] = []
        for rule in newRules.rules {
            let body = newText(rule.body).trimmingCharacters(in: .whitespacesAndNewlines)
            let existing = CSSRules(result)
            if let old = existing.rule(for: rule.selector) {
                var units = Array(result.utf16)
                units.replaceSubrange(old.body, with: Array(" \(body) ".utf16))
                result = String(decoding: units, as: UTF16.self)
            } else {
                appended.append("\(rule.selector) { \(body) }")
            }
        }
        let leftover = Self.removing(newRules.rules.map(\.range), from: newUnits).trimmingCharacters(in: .whitespacesAndNewlines)
        if !leftover.isEmpty { appended.append(leftover) }
        guard !appended.isEmpty else { return result }
        let trimmed = result.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
        let newline = current.contains("\r\n") ? "\r\n" : "\n"
        return trimmed + newline + appended.joined(separator: newline) + newline
    }

    private static func removing(_ ranges: [Range<Int>], from units: [UTF16.CodeUnit]) -> String {
        var kept = units
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) { kept.removeSubrange(range) }
        return String(decoding: kept, as: UTF16.self)
    }

    private static func strippingCommentsAndStrings(_ css: String) -> String {
        css.replacingOccurrences(of: #"/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, with: "", options: .regularExpression)
    }
}
