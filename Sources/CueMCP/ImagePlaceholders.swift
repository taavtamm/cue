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

    private static let dataURI = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: #"(data:[A-Za-z0-9.+/-]+;base64,)([A-Za-z0-9+/=]{2000,})"#
    )
    private static let placeholder = try! NSRegularExpression( // swiftlint:disable:this force_try
        pattern: #"CUE-IMAGE-([0-9a-f]{16})"#
    )

    /// Replaces large embedded images with placeholders.
    static func shorten(_ html: String) -> String {
        replace(dataURI, in: html) { match, text in
            let prefix = text.substring(with: match.range(at: 1))
            return prefix + marker + key(text.substring(with: match.range(at: 2)))
        }
    }

    /// Puts the images back, looking each placeholder up among the images in
    /// `deck`. Throws if Claude sent a placeholder the deck doesn't have.
    static func restore(_ html: String, from deck: String) throws -> String {
        guard html.contains(marker) else { return html }
        var images: [String: String] = [:]
        let source = deck as NSString
        for match in dataURI.matches(in: deck, range: NSRange(location: 0, length: source.length)) {
            let data = source.substring(with: match.range(at: 2))
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
