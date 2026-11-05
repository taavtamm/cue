import CryptoKit
import Foundation

/// Slides often embed images as base64 `data:` URIs of hundreds of
/// kilobytes. Claude never needs those bytes, and they pushed the slide's
/// own text past the size limit. So HTML going to Claude carries a short
/// placeholder per large image, and HTML coming back has them restored from
/// the deck, so a slide Claude rewrites keeps its pictures.
///
///     data:image/png;base64,iVBORw0…   →   data:image/png;base64,CUE-IMAGE-3f2a9c1d07b4e6a8
enum ImagePlaceholders {
    static let marker = "CUE-IMAGE-"
    /// Shorter data URIs stay as they are.
    static let threshold = 2_000

    private static let placeholder = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: #"CUE-IMAGE-([0-9a-f]{16})"#
    )

    /// Replaces large embedded images with placeholders.
    static func shorten(_ html: String) -> String {
        let source = html as NSString
        var output = ""
        var last = 0
        for data in largeImages(in: html) {
            output += source.substring(with: NSRange(location: last, length: data.location - last))
            output += marker + key(source.substring(with: data))
            last = data.location + data.length
        }
        return output + source.substring(from: last)
    }

    /// Puts the images back, looking each placeholder up among the images in
    /// `deck`. Throws if Claude sent a placeholder the deck doesn't have.
    static func restore(_ html: String, from deck: String) throws -> String {
        guard html.contains(marker) else { return html }
        var images: [String: String] = [:]
        let source = deck as NSString
        for range in largeImages(in: deck) {
            let data = source.substring(with: range)
            images[key(data)] = data
        }
        var missing: String?
        let restored = replace(placeholder, in: html) { match, text in
            let id = text.substring(with: match.range(at: 1))
            guard let data = images[id] else {
                missing = id
                return text.substring(with: match.range)
            }
            return data
        }
        if let missing {
            throw CueMCPError.invalid("The image placeholder \(marker)\(missing) isn't in this deck. "
                + "Keep the placeholders exactly as get_slide_html returned them.")
        }
        return restored
    }

    /// The base64 payload of each large `data:…;base64,` URI, in UTF-16
    /// ranges. A plain scan, not a regex: ICU's counted repeat overflows its
    /// stack on a megabyte of base64 and silently reports no match.
    static func largeImages(in text: String) -> [NSRange] {
        let source = text as NSString
        let length = source.length
        var ranges: [NSRange] = []
        var search = NSRange(location: 0, length: length)
        while true {
            let found = source.range(of: ";base64,", options: .literal, range: search)
            guard found.location != NSNotFound else { break }
            let start = found.location + found.length
            var end = start
            while end < length, isBase64(source.character(at: end)) { end += 1 }
            if end - start >= threshold, hasMediaType(source, before: found.location) {
                ranges.append(NSRange(location: start, length: end - start))
            }
            search = NSRange(location: end, length: length - end)
        }
        return ranges
    }

    /// `data:<type>` right before `;base64,`.
    private static func hasMediaType(_ source: NSString, before index: Int) -> Bool {
        var start = index
        while start > 0, start > index - 128, isMediaTypeCharacter(source.character(at: start - 1)) { start -= 1 }
        guard start < index, start >= 5 else { return false }
        return source.substring(with: NSRange(location: start - 5, length: 5)).lowercased() == "data:"
    }

    private static func isBase64(_ c: unichar) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 43 || c == 47 || c == 61
    }

    private static func isMediaTypeCharacter(_ c: unichar) -> Bool {
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 43 || c == 45 || c == 46 || c == 47
    }

    private static func key(_ base64: String) -> String {
        SHA256.hash(data: Data(base64.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
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
