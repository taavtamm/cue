import Foundation

/// A lightweight element tree exported from parse5. Only elements are kept
/// (text is summarised in `text`), each with exact source offsets.
public final class HTMLNode: Sendable {
    public let tag: String
    public let attributes: [String: String]
    /// Source range of each attribute (name="value"), keyed by name.
    public let attributeRanges: [String: SourceRange]
    /// Whole element, from `<tag` to the end of `</tag>`.
    public let range: SourceRange?
    /// The start tag only, `<tag ...>`.
    public let startTagRange: SourceRange?
    /// The end tag, `</tag>`. Nil for void elements and implied end tags.
    public let endTagRange: SourceRange?
    /// Text content directly inside this element (not descendants), trimmed.
    public let text: String
    public let children: [HTMLNode]

    public init(
        tag: String,
        attributes: [String: String] = [:],
        attributeRanges: [String: SourceRange] = [:],
        range: SourceRange? = nil,
        startTagRange: SourceRange? = nil,
        endTagRange: SourceRange? = nil,
        text: String = "",
        children: [HTMLNode] = []
    ) {
        self.tag = tag
        self.attributes = attributes
        self.attributeRanges = attributeRanges
        self.range = range
        self.startTagRange = startTagRange
        self.endTagRange = endTagRange
        self.text = text
        self.children = children
    }

    public subscript(attribute name: String) -> String? { attributes[name] }
    /// Shorthand for `self[attribute: name]`.
    public subscript(_ name: String) -> String? { attributes[name] }

    public var classes: Set<String> {
        Set((attributes["class"] ?? "").split(whereSeparator: \.isWhitespace).map(String.init))
    }
}
