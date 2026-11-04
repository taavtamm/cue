import CoreGraphics
import CueCore
import CueRender
import Foundation

/// One move or resize in progress. Built when the drag starts (so snapping
/// targets and the canvas scale are read once), updated on every mouse
/// move without touching the source, and committed as one edit on release.
public struct ElementDrag: Sendable {
    public enum Kind: Sendable, Equatable {
        case move
        case resize(ElementPlacement.Handle)
    }

    public let kind: Kind
    public let cueID: String
    public let path: ElementPath
    /// The element's box when the drag began, in canvas pixels.
    public let start: CGRect
    public let geometry: CanvasGeometry
    let inlineStyle: String
    let isCueElement: Bool
    let snapping: Snapping

    /// The box now, in canvas pixels, and the guide lines to draw.
    public private(set) var frame: CGRect
    public private(set) var guides: [Snapping.Guide] = []

    init(kind: Kind, element: MappedElement, start: CGRect, geometry: CanvasGeometry, snapping: Snapping) {
        self.kind = kind
        cueID = element.cueID
        path = element.path
        self.start = start
        self.geometry = geometry
        inlineStyle = element.attributes["style"] ?? ""
        isCueElement = element.attributes["data-cue-element"] != nil
        self.snapping = snapping
        frame = start
    }

    /// Follows the pointer: `delta` is how far it moved since the drag began,
    /// in canvas pixels. Shift constrains; Command turns snapping off.
    public mutating func update(delta: CGSize, shift: Bool, noSnapping: Bool) {
        switch kind {
        case .move:
            let moved = ElementPlacement.moved(start, by: delta, constrained: shift)
            (frame, guides) = noSnapping ? (moved, []) : snapping.snap(moving: moved)
        case .resize(let handle):
            let resized = ElementPlacement.resized(start, handle: handle, by: delta, keepAspect: shift)
            (frame, guides) = noSnapping || shift ? (resized, []) : snapping.snap(resizing: resized, handle: handle)
        }
    }

    /// The inline style changes that put the element at `frame`.
    public var changes: [StyleChange] {
        ElementPlacement.changes(from: start, to: frame, inlineStyle: inlineStyle, isCueElement: isCueElement)
    }

    /// The selection box to draw now, in the surface's coordinates.
    public var viewFrame: CGRect { geometry.viewRect(fromCanvas: frame) }
}
