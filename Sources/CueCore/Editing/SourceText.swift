import Foundation

/// UTF-16 slicing for source text. parse5 offsets are JavaScript string
/// indices, which are UTF-16 code units, so every edit works in those.
struct SourceText {
    let units: [UTF16.CodeUnit]

    init(_ text: String) {
        units = Array(text.utf16)
    }

    var count: Int { units.count }

    func slice(_ range: SourceRange) -> String {
        let start = max(0, min(range.start, units.count))
        let end = max(start, min(range.end, units.count))
        return String(decoding: units[start..<end], as: UTF16.self)
    }

    func unit(at offset: Int) -> Character? {
        guard units.indices.contains(offset), let scalar = Unicode.Scalar(units[offset]) else { return nil }
        return Character(scalar)
    }

    /// The file's line ending, so inserted lines match the rest of the file.
    var lineEnding: String {
        guard let newline = units.firstIndex(of: 10) else { return "\n" }
        return newline > 0 && units[newline - 1] == 13 ? "\r\n" : "\n"
    }

    /// Offset of the first non-whitespace unit at or after `offset`.
    func skipWhitespace(from offset: Int) -> Int {
        var index = offset
        while let character = unit(at: index), character.isWhitespace { index += 1 }
        return index
    }

    /// Offset just after the whitespace that ends right at `offset`, searching backwards.
    func whitespaceStart(before offset: Int) -> Int {
        var index = offset
        while index > 0, let character = unit(at: index - 1), character.isWhitespace { index -= 1 }
        return index
    }

    /// The indentation of the line containing `offset` (spaces and tabs only).
    func indentation(ofLineAt offset: Int) -> String {
        var start = offset
        while start > 0, let character = unit(at: start - 1), character != "\n", character != "\r" { start -= 1 }
        var end = start
        while let character = unit(at: end), character == " " || character == "\t" { end += 1 }
        return slice(SourceRange(start: start, end: end))
    }
}
