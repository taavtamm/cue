import AppKit

/// Which of a deck's font families this Mac doesn't have. Fonts are never
/// embedded in exports, so PowerPoint substitutes the missing ones.
@MainActor
enum FontCheck {
    static func missing(_ families: Set<String>) -> [String] {
        let installed = Set(NSFontManager.shared.availableFontFamilies.map { $0.lowercased() })
        return families
            .map(PptxTextXML.fontFamily)
            .filter { !installed.contains($0.lowercased()) }
            .reduce(into: Set<String>()) { $0.insert($1) }
            .sorted()
    }
}
