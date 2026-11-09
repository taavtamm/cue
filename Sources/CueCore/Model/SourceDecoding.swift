import Foundation

/// Picks the text encoding of an HTML file the way browsers do, simplified:
/// byte-order mark, then `<meta charset>` in the first 1024 bytes, then UTF-8,
/// then Windows-1252, then ISO-8859-1. Foundation's Windows-1252 refuses the
/// five bytes it leaves undefined (0x81, 0x8D, 0x8F, 0x90, 0x9D); ISO-8859-1
/// maps every byte, so decoding always succeeds and re-encodes losslessly.
enum SourceDecoding {
    static func decode(_ data: Data) throws -> (String, String.Encoding) {
        for encoding in candidates(for: data) {
            if let text = String(data: data, encoding: encoding) { return (text, encoding) }
        }
        throw DeckDocumentError.undecodable
    }

    static func candidates(for data: Data) -> [String.Encoding] {
        if let bom = byteOrderMark(data) { return [bom] }
        let declared = declaredCharset(data).flatMap(encoding(named:))
        return [declared, .utf8, .windowsCP1252, .isoLatin1].compactMap { $0 }
    }

    private static func byteOrderMark(_ data: Data) -> String.Encoding? {
        let bytes = [UInt8](data.prefix(3))
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { return .utf8 }
        if bytes.starts(with: [0xFE, 0xFF]) { return .utf16BigEndian }
        if bytes.starts(with: [0xFF, 0xFE]) { return .utf16LittleEndian }
        return nil
    }

    static func declaredCharset(_ data: Data) -> String? {
        let head = String(decoding: data.prefix(1024), as: UTF8.self).lowercased()
        let pattern = #"charset\s*=\s*["']?([a-z0-9_\-]+)"#
        guard let match = head.range(of: pattern, options: .regularExpression) else { return nil }
        let value = head[match].split(separator: "=").last ?? ""
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
    }

    private static func encoding(named name: String) -> String.Encoding? {
        switch name {
        case "utf-8", "utf8": .utf8
        case "windows-1252", "iso-8859-1", "latin1", "us-ascii", "ascii": .windowsCP1252
        // A `<meta>` readable as ASCII means the file isn't really UTF-16;
        // the HTML spec says to treat such a declaration as UTF-8.
        case "utf-16", "utf-16le", "utf-16be": .utf8
        case "shift_jis": .shiftJIS
        case "euc-jp": .japaneseEUC
        default: nil
        }
    }
}
