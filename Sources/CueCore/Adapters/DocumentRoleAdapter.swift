import Foundation

/// Decks that mark slides semantically:
/// `data-document-role="page"` or `aria-roledescription="slide"`.
public struct DocumentRoleAdapter: DeckAdapter {
    public let kind = AdapterKind.documentRole
    public init() {}

    static let selectors = ["[data-document-role=\"page\"]", "[aria-roledescription=\"slide\"]"]

    public func detect(_ input: AdapterInput) -> DeckStructure? {
        guard let (selector, slides) = ClaudeDesignAdapter.firstMatching(Self.selectors, in: input.root) else {
            return nil
        }
        let infos = slides.enumerated().map { index, slide in
            slide.info(index: index, notesAttributes: ["data-speaker-notes", "data-notes"])
        }
        return DeckStructure(
            adapter: kind,
            renderMode: .cueDriven,
            canvas: CanvasParsing.cueCanvas(input.root) ?? .hd,
            slideSelector: selector,
            slides: infos
        )
    }
}
