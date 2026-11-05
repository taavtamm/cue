import CryptoKit
import Foundation

/// Like `ImagePlaceholders`, for whole `<style>` and `<script>` blocks too
/// big to send Claude (Fernwick's stylesheet is ~545 KB). Their contents are
/// swapped for a comment naming the block; HTML coming back has them restored
/// from the deck, so a rewritten `<head>` or document keeps them as they were.
///
///     <style>/* CUE-BLOCK-3f2a9c1d07b4e6a8: 545 KB of the deck's own CSS, kept as is (see get_styles) */</style>
enum BlockPlaceholders {
    static let threshold = 20_000
    static let marker = "CUE-BLOCK-"

    private static let block = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: #"(<(style|script)\b[^>]*>)([\s\S]*?)(</\2\s*>)"#, options: [.caseInsensitive]
    )
    private static let placeholder = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: #"/\* CUE-BLOCK-([0-9a-f]{16})[^*]*\*/"#
    )

    static func shorten(_ html: String) -> String {
        replace(block, in: html) { match, text in
            let content = text.substring(with: match.range(at: 3))
            guard content.utf16.count > threshold else { return text.substring(with: match.range) }
            let kind = text.substring(with: match.range(at: 2)).lowercased() == "style" ? "CSS (see get_styles)" : "script"
            let note = "/* \(marker)\(key(content)): \(content.utf8.count / 1024) KB of the deck's own \(kind), kept as is */"
            return text.substring(with: match.range(at: 1)) + note + text.substring(with: match.range(at: 4))
        }
    }

    static func restore(_ html: String, from deck: String) throws -> String {
        guard html.contains(marker) else { return html }
        var contents: [String: String] = [:]
        let source = deck as NSString
        for match in block.matches(in: deck, range: NSRange(location: 0, length: source.length)) {
            let content = source.substring(with: match.range(at: 3))
            if content.utf16.count > threshold { contents[key(content)] = content }
        }
        var missing: String?
        let restored = replace(placeholder, in: html) { match, text in
            let id = text.substring(with: match.range(at: 1))
            guard let content = contents[id] else { missing = id; return text.substring(with: match.range) }
            return content
        }
        if let missing {
            throw CueMCPError.invalid("The placeholder \(marker)\(missing) isn't in this deck. Keep block placeholders exactly as Cue sent them.")
        }
        return restored
    }

    /// Images and big blocks both, the way every whole-document read goes out.
    static func shortenAll(_ html: String) -> String { ImagePlaceholders.shorten(shorten(html)) }

    static func restoreAll(_ html: String, from deck: String) throws -> String {
        try ImagePlaceholders.restore(try restore(html, from: deck), from: deck)
    }

    private static func key(_ content: String) -> String {
        SHA256.hash(data: Data(content.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private static func replace(
        _ regex: NSRegularExpression, in text: String, _ make: (NSTextCheckingResult, NSString) -> String
    ) -> String {
        let source = text as NSString
        var output = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            output += source.substring(with: NSRange(location: last, length: match.range.location - last))
            output += make(match, source)
            last = match.range.location + match.range.length
        }
        return output + source.substring(from: last)
    }
}
