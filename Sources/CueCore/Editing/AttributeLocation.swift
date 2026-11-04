import Foundation

/// Where one attribute sits in the source: `name="value"` as a whole, and
/// the value inside its quotes, so an edit can replace just the value.
public struct AttributeLocation: Sendable, Equatable {
    /// `name="value"`, as parse5 reports it.
    public let range: SourceRange
    /// The value without quotes. Nil for a bare attribute like `hidden`.
    public let valueRange: SourceRange?
    /// `"`, `'`, or nil when the value is unquoted.
    public let quote: Character?

    /// Reads the value's position from the attribute's text.
    init(range: SourceRange, in text: SourceText) {
        self.range = range
        var index = range.start
        while index < range.end, let character = text.unit(at: index), character != "=" { index += 1 }
        guard index < range.end else {
            valueRange = nil
            quote = nil
            return
        }
        index = text.skipWhitespace(from: index + 1)
        if let character = text.unit(at: index), character == "\"" || character == "'", index < range.end {
            quote = character
            valueRange = SourceRange(start: index + 1, end: max(index + 1, range.end - 1))
        } else {
            quote = nil
            valueRange = SourceRange(start: index, end: range.end)
        }
    }
}
