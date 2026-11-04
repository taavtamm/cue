import Foundation

/// JSON objects as text, for embedding in JavaScript and rule lists.
enum JSONText {
    /// `fallback` is returned only if `object` isn't valid JSON, which is a programming error.
    static func string(_ object: Any, sortedKeys: Bool = false, fallback: String = "{}") -> String {
        let options: JSONSerialization.WritingOptions = sortedKeys ? [.sortedKeys] : []
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: options),
              let text = String(bytes: data, encoding: .utf8)
        else { return fallback }
        return text
    }
}
