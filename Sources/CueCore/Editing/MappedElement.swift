import Foundation

/// One element of the deck with everything an edit needs to find it in the
/// source. `cueID` is its position in document order; CueBridge puts the same
/// number on the live DOM element as `data-cue-id`, in memory only.
public struct MappedElement: Sendable, Equatable {
    public let cueID: String
    public let tag: String
    /// Child-element indices from `<html>`.
    public let path: ElementPath
    public let attributes: [String: String]
    /// From `<tag` to the end of `</tag>`. Nil for elements the parser implied.
    public let range: SourceRange?
    public let startTag: SourceRange?
    public let endTag: SourceRange?
    public let attributeLocations: [String: AttributeLocation]
    public let childCount: Int

    /// Between the start and end tags. Nil without both tags.
    public var innerRange: SourceRange? {
        guard let startTag, let endTag else { return nil }
        return SourceRange(start: startTag.end, end: endTag.start)
    }

    public var isLeaf: Bool { childCount == 0 }

    /// Elements whose content is code or raw text.
    static let rawTextTags: Set<String> = ["script", "style", "xmp", "iframe", "noembed", "noframes", "plaintext"]
    static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr",
    ]
}
