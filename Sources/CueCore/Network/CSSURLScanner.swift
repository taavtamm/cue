import Foundation

/// Finds remote URLs in CSS text: `@import`, `@font-face` sources and any
/// other `url(...)`. A light scan, not a CSS parser; it errs towards
/// reporting a host rather than missing one.
enum CSSURLScanner {
    static func resources(in css: String) -> [RemoteResource] {
        var found: [RemoteResource] = []
        let fontFaces = matches(of: #"@font-face\s*\{[^}]*\}"#, in: css)
        for block in fontFaces {
            for url in urls(in: block) {
                if let host = RemoteResource.host(ofURL: url) {
                    found.append(RemoteResource(host: host, kind: .fonts, origin: .stylesheet))
                }
            }
        }
        let withoutFontFaces = fontFaces.reduce(css) { $0.replacingOccurrences(of: $1, with: "") }
        for url in imports(in: withoutFontFaces) {
            if let host = RemoteResource.host(ofURL: url) {
                let kind: RemoteResourceKind = FontHosts.isFontHost(host) ? .fonts : .styles
                found.append(RemoteResource(host: host, kind: kind, origin: .stylesheet))
            }
        }
        let rest = matches(of: #"@import[^;]*;?"#, in: withoutFontFaces)
            .reduce(withoutFontFaces) { $0.replacingOccurrences(of: $1, with: "") }
        for url in urls(in: rest) {
            if let host = RemoteResource.host(ofURL: url) {
                let kind: RemoteResourceKind = FontHosts.isFontHost(host) ? .fonts : .images
                found.append(RemoteResource(host: host, kind: kind, origin: .stylesheet))
            }
        }
        return found
    }

    /// Arguments of every `url(...)`, quotes removed.
    static func urls(in css: String) -> [String] {
        captures(of: #"url\(\s*['"]?([^'")\s]+)['"]?\s*\)"#, in: css)
    }

    /// `@import "x.css"` and `@import url(x.css)`.
    static func imports(in css: String) -> [String] {
        captures(of: #"@import\s+(?:url\()?\s*['"]?([^'")\s;]+)"#, in: css)
    }

    private static func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        let all = NSRange(location: 0, length: ns.length)
        return regex.matches(in: text, range: all).map { ns.substring(with: $0.range) }
    }

    private static func captures(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            $0.numberOfRanges > 1 && $0.range(at: 1).location != NSNotFound ? ns.substring(with: $0.range(at: 1)) : nil
        }
    }
}
