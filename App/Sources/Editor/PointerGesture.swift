import CoreGraphics
import CueCore
import CueEditor

/// What a press on the canvas turns into: a click (select), or once the
/// pointer has moved a few points, a move or resize of the selection.
struct PointerGesture {
    enum Intent: Equatable {
        case none
        /// Pressed on the selection (or a handle): dragging moves or resizes it.
        case drag(ElementDrag.Kind)
        /// Pressed elsewhere: select what's there, then a drag moves it.
        case selectThenMove
    }

    var intent = Intent.none
    var start = CGPoint.zero
    var duplicates = false
    /// A drag is being set up (snap targets are being read).
    var isPreparing = false
    var hasMoved = false
    /// The click that selects what was pressed, when it wasn't the selection.
    var selecting: Task<Void, Never>?

    /// Pointer travel (in view points) before a press becomes a drag.
    static let dragThreshold: CGFloat = 3

    func passedThreshold(at point: CGPoint) -> Bool {
        hypot(point.x - start.x, point.y - start.y) >= Self.dragThreshold
    }
}
