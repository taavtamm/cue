import CoreText
import Foundation

/// Turns a font name from a presentation into a CSS `font-family` list with
/// sensible fallbacks, and notes fonts this Mac doesn't have.
final class FontCatalog: @unchecked Sendable {
    private let installed: Set<String>
    private(set) var missing: Set<String> = []
    private let lock = NSLock()

    init() {
        let names = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        installed = Set(names.map { $0.lowercased() })
    }

    func cssFamily(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return Self.sans }
        let clean = name.replacingOccurrences(of: "\"", with: "")
        if !installed.contains(clean.lowercased()) {
            lock.lock()
            missing.insert(clean)
            lock.unlock()
        }
        let lower = clean.lowercased()
        let fallback: String
        if Self.serifHints.contains(where: lower.contains) {
            fallback = Self.serif
        } else if Self.monoHints.contains(where: lower.contains) {
            fallback = Self.mono
        } else if lower.hasPrefix("calibri") {
            fallback = "Carlito, " + Self.sans
        } else {
            fallback = Self.sans
        }
        return "\"\(clean)\", \(fallback)"
    }

    static let sans = "-apple-system, \"Helvetica Neue\", Helvetica, Arial, sans-serif"
    static let serif = "Georgia, \"Times New Roman\", serif"
    static let mono = "Menlo, Monaco, \"Courier New\", monospace"
    private static let serifHints = ["times", "georgia", "cambria", "garamond", "palatino", "baskerville", "serif",
                                     "book antiqua", "didot", "bodoni", "minion", "caslon"]
    private static let monoHints = ["courier", "consolas", "menlo", "monaco", "mono", "code"]
}
