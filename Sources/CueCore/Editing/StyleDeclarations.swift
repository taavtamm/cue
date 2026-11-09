import Foundation

/// The declarations in a CSS declaration list (an inline `style` attribute,
/// or the body of a rule), read from source text without normalising it.
/// Edits come back as patches relative to the start of the text, so the
/// rest of the declarations keep their exact formatting.
struct StyleDeclarations {
    struct Declaration {
        let property: String
        /// `prop: value` without the trailing `;`.
        let range: Range<Int>
        let valueRange: Range<Int>
        /// The `;` after it, if any.
        let semicolon: Int?
    }

    let text: [Character]
    private(set) var declarations: [Declaration] = []

    init(_ source: String) {
        text = Array(source)
        declarations = Self.scan(text)
    }

    /// Each declaration as written (`prop: value`, trimmed, without its `;`).
    /// Unlike splitting on `;`, this keeps `font-family: &quot;A&quot;, B` whole.
    var sourceTexts: [(property: String, text: String)] {
        declarations.map { ($0.property, String(text[$0.range])) }
    }

    /// Patches that set `property` to `value`, or remove it when `value` is nil.
    func patches(setting property: String, to value: String?) -> [(range: Range<Int>, replacement: String)] {
        let existing = declarations.last { $0.property.caseInsensitiveCompare(property) == .orderedSame }
        switch (existing, value) {
        case (let declaration?, let value?):
            return [(declaration.valueRange, value)]
        case (let declaration?, nil):
            return [removal(of: declaration)]
        case (nil, let value?):
            return [addition(of: "\(property): \(value)")]
        case (nil, nil):
            return []
        }
    }

    /// The same patches with UTF-16 offsets, as `SourcePatch` needs.
    func sourcePatches(setting property: String, to value: String?, base: Int) -> [SourcePatch] {
        patches(setting: property, to: value).map { patch in
            let start = base + utf16Offset(patch.range.lowerBound)
            let end = base + utf16Offset(patch.range.upperBound)
            return SourcePatch(range: SourceRange(start: start, end: end), replacement: patch.replacement)
        }
    }

    private func utf16Offset(_ characterIndex: Int) -> Int {
        String(text[0..<characterIndex]).utf16.count
    }

    private func addition(of declaration: String) -> (range: Range<Int>, replacement: String) {
        var end = text.count
        while end > 0, text[end - 1].isWhitespace { end -= 1 }
        if end == 0 { return (0..<text.count, declaration) }
        if text[end - 1] == ";" { return (end..<end, " \(declaration);") }
        return (end..<end, "; \(declaration)")
    }

    private func removal(of declaration: Declaration) -> (range: Range<Int>, replacement: String) {
        if let semicolon = declaration.semicolon {
            var end = semicolon + 1
            while end < text.count, text[end].isWhitespace { end += 1 }
            return (declaration.range.lowerBound..<end, "")
        }
        // Last declaration without a `;`: take the separator before it instead.
        var start = declaration.range.lowerBound
        while start > 0, text[start - 1].isWhitespace { start -= 1 }
        if start > 0, text[start - 1] == ";" { start -= 1 }
        return (start..<declaration.range.upperBound, "")
    }

    /// Splits on top-level `;`, ignoring ones inside quotes, parentheses and
    /// HTML entities like `&quot;` (common in inline styles).
    private static func scan(_ text: [Character]) -> [Declaration] {
        var result: [Declaration] = []
        var start = 0
        var index = 0
        var depth = 0
        var quote: Character?
        func finish(at end: Int, semicolon: Int?) {
            if let declaration = declaration(in: text, from: start, to: end, semicolon: semicolon) {
                result.append(declaration)
            }
        }
        while index < text.count {
            if let length = entityLength(text, at: index) {
                if text[index..<(index + length)].elementsEqual("&quot;") { quote = quote == nil ? "\"" : nil }
                index += length
                continue
            }
            let character = text[index]
            if let open = quote {
                if character == open { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "(" {
                depth += 1
            } else if character == ")" {
                depth = max(0, depth - 1)
            } else if character == ";" && depth == 0 {
                finish(at: index, semicolon: index)
                start = index + 1
            }
            index += 1
        }
        finish(at: text.count, semicolon: nil)
        return result
    }

    private static func declaration(in text: [Character], from: Int, to: Int, semicolon: Int?) -> Declaration? {
        var start = from
        while start < to, text[start].isWhitespace { start += 1 }
        var end = to
        while end > start, text[end - 1].isWhitespace { end -= 1 }
        guard start < end, let colon = text[start..<end].firstIndex(of: ":") else { return nil }
        var nameEnd = colon
        while nameEnd > start, text[nameEnd - 1].isWhitespace { nameEnd -= 1 }
        var valueStart = colon + 1
        while valueStart < end, text[valueStart].isWhitespace { valueStart += 1 }
        let property = String(text[start..<nameEnd]).lowercased()
        return Declaration(property: property, range: start..<end, valueRange: valueStart..<end, semicolon: semicolon)
    }

    /// `&name;` or `&#123;` starting at `index`.
    private static func entityLength(_ text: [Character], at index: Int) -> Int? {
        guard text[index] == "&" else { return nil }
        var end = index + 1
        while end < text.count, end - index < 12, text[end].isLetter || text[end].isNumber || text[end] == "#" {
            end += 1
        }
        return end < text.count && text[end] == ";" && end > index + 1 ? end - index + 1 : nil
    }

    static func isValidProperty(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}
