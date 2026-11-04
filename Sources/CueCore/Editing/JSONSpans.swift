import Foundation

/// Finds where values sit inside JSON text without re-serialising it, so a
/// change to one slide's entry patches only that entry. Offsets are UTF-16.
struct JSONSpans {
    enum Key: Equatable {
        case field(String)
        case index(Int)
    }

    private let units: [UTF16.CodeUnit]

    init(_ text: String) {
        units = Array(text.utf16)
    }

    /// The range of the value at `path`, e.g. `[.field("slides"), .index(2), .field("steps")]`.
    func range(at path: [Key]) throws -> Range<Int> {
        var range = try value(from: skip(0))
        for key in path {
            guard let child = try children(of: range).first(where: { $0.key == key }) else {
                throw EditError.malformedSource("deck-motion JSON has no \(key)")
            }
            range = child.range
        }
        return range
    }

    /// The element ranges of the array at `path`.
    func elements(at path: [Key]) throws -> [Range<Int>] {
        try children(of: range(at: path)).map(\.range)
    }

    func text(_ range: Range<Int>) -> String {
        String(decoding: units[range], as: UTF16.self)
    }

    // MARK: Scanning

    private func children(of range: Range<Int>) throws -> [(key: Key, range: Range<Int>)] {
        guard let open = units[safe: range.lowerBound], open == 0x7B || open == 0x5B else { return [] }
        let isObject = open == 0x7B
        var result: [(Key, Range<Int>)] = []
        var index = skip(range.lowerBound + 1)
        while index < range.upperBound - 1 {
            var key = Key.index(result.count)
            if isObject {
                let name = try string(from: index)
                key = .field(text((name.lowerBound + 1)..<(name.upperBound - 1)))
                index = skip(name.upperBound)
                guard units[safe: index] == 0x3A else { throw EditError.malformedSource("expected :") }
                index = skip(index + 1)
            }
            let child = try value(from: index)
            result.append((key, child))
            index = skip(child.upperBound)
            if units[safe: index] == 0x2C { index = skip(index + 1) }
        }
        return result
    }

    /// The extent of the value starting at `start`.
    private func value(from start: Int) throws -> Range<Int> {
        guard let first = units[safe: start] else { throw EditError.malformedSource("unexpected end of JSON") }
        switch first {
        case 0x22: return try string(from: start)
        case 0x7B, 0x5B: return try container(from: start)
        default:
            var end = start
            while let unit = units[safe: end], !",]} \n\r\t".utf16.contains(unit) { end += 1 }
            return start..<end
        }
    }

    private func string(from start: Int) throws -> Range<Int> {
        guard units[safe: start] == 0x22 else { throw EditError.malformedSource("expected a string") }
        var index = start + 1
        while let unit = units[safe: index] {
            if unit == 0x5C { index += 2; continue }
            if unit == 0x22 { return start..<(index + 1) }
            index += 1
        }
        throw EditError.malformedSource("unterminated string")
    }

    private func container(from start: Int) throws -> Range<Int> {
        var depth = 0
        var index = start
        while let unit = units[safe: index] {
            switch unit {
            case 0x22: index = try string(from: index).upperBound; continue
            case 0x7B, 0x5B: depth += 1
            case 0x7D, 0x5D:
                depth -= 1
                if depth == 0 { return start..<(index + 1) }
            default: break
            }
            index += 1
        }
        throw EditError.malformedSource("unbalanced JSON")
    }

    private func skip(_ start: Int) -> Int {
        var index = start
        while let unit = units[safe: index], unit == 0x20 || unit == 0x0A || unit == 0x0D || unit == 0x09 { index += 1 }
        return index
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// JSON text that is safe inside `<script>`: `<`, `>` and `&` as `\u00xx`,
/// the way Claude Design writes its deck-motion block.
enum ScriptSafeJSON {
    static func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard let json = String(bytes: data, encoding: .utf8) else { throw EditError.malformedSource("JSON") }
        return json
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "&", with: "\\u0026")
    }
}
