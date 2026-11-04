import Foundation

/// Escaping for HTML written by the importers (always UTF-8 output).
enum HTMLText {
    static func text(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(character)
            }
        }
        return out
    }

    static func attribute(_ value: String) -> String {
        text(value).replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// A relative URL path with each segment percent-encoded (asset folders have spaces).
    static func urlPath(_ components: [String]) -> String {
        components.map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) ?? $0 }
            .joined(separator: "/")
    }
}
