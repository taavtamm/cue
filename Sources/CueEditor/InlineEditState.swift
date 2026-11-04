import CoreGraphics
import Foundation

/// Text being edited directly on the slide.
public struct InlineEditState: Sendable, Equatable {
    public let cueID: String
    public let path: [Int]
    /// The insertion point, in canvas coordinates. Nil before the page reports it.
    public var caret: CGRect?
    /// False while a range is selected; the glowing caret hides then.
    public var collapsed = true
    /// Bumped on every keystroke, so the caret stays solid while typing.
    public var inputCount = 0
}
