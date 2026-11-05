import Foundation

extension SourceEditor {
    /// Swaps a slide's whole element for new markup. The new markup must be
    /// one element of the same kind, so the deck still finds it as a slide.
    func replaceSlide(_ index: Int, with html: String) throws -> SourceEdit {
        let slide = try slideElement(index)
        guard let range = slide.range else { throw EditError.elementHasNoSource }
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("<\(slide.tag)") else {
            throw EditError.unsupported("The new slide must be one <\(slide.tag)> element, like the one it replaces.")
        }
        return SourceEdit([SourcePatch(range: range, replacement: trimmed)])
    }
}
