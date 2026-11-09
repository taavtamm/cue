import Foundation

/// Recognises one deck format and describes its slides.
/// Return nil when the deck isn't in this adapter's format.
public protocol DeckAdapter: Sendable {
    var kind: AdapterKind { get }
    func detect(_ input: AdapterInput) -> DeckStructure?
}

/// What every adapter reads: the parsed tree and the exact source text.
public struct AdapterInput {
    /// The `<html>` element.
    public let root: HTMLNode
    public let source: String

    public init(root: HTMLNode, source: String) {
        self.root = root
        self.source = source
    }

    /// The source text inside `range` (UTF-16 offsets, as parse5 reports them).
    public func text(in range: SourceRange) -> String {
        let utf16 = source.utf16
        let start = utf16.index(utf16.startIndex, offsetBy: range.start)
        let end = utf16.index(start, offsetBy: range.length)
        return String(utf16[start..<end]) ?? ""
    }

    /// The text between an element's start and end tags (for `<script>` bodies).
    /// Without an end tag (cut off at the end of the file), up to the element's end.
    public func innerText(of node: HTMLNode) -> String {
        guard let whole = node.range, let startTag = node.startTagRange else { return "" }
        let end = max(startTag.end, node.endTagRange?.start ?? whole.end)
        return text(in: SourceRange(start: startTag.end, end: end))
    }
}
