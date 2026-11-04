import CoreGraphics
import Foundation
import Observation

/// How far the editor canvas is zoomed in. 1 is "fit": the whole slide in
/// the window. Per editor window; never saved to the deck.
@MainActor @Observable
public final class CanvasZoom {
    public static let range: ClosedRange<CGFloat> = 1...8
    /// The steps ⌘+ and ⌘− move through, and the readout menu offers.
    public static let steps: [CGFloat] = [1, 1.5, 2, 3, 4, 6, 8]

    public private(set) var scale: CGFloat = 1

    public init() {}

    public var isFit: Bool { scale <= 1.001 }

    /// "Fit" or "200%".
    public var readout: String { isFit ? "Fit" : "\(Int((scale * 100).rounded()))%" }

    @discardableResult
    public func set(_ value: CGFloat) -> CGFloat {
        scale = min(Self.range.upperBound, max(Self.range.lowerBound, value))
        return scale
    }

    public func zoomedIn() -> CGFloat { Self.steps.first { $0 > scale + 0.001 } ?? Self.range.upperBound }
    public func zoomedOut() -> CGFloat { Self.steps.last { $0 < scale - 0.001 } ?? Self.range.lowerBound }

    /// Two-finger double-tap: fit ↔ 200%.
    public func smartMagnified() -> CGFloat { isFit ? 2 : 1 }

    /// The scroll origin that keeps `anchor` (a point in the zoomed content,
    /// before the change) under the same spot on screen after zooming from
    /// `old` to `new`. `visibleOrigin` is the scroll position before.
    public static func anchoredOrigin(anchor: CGPoint, visibleOrigin: CGPoint, old: CGFloat, new: CGFloat) -> CGPoint {
        let factor = new / max(0.0001, old)
        let onScreen = CGPoint(x: anchor.x - visibleOrigin.x, y: anchor.y - visibleOrigin.y)
        return CGPoint(x: anchor.x * factor - onScreen.x, y: anchor.y * factor - onScreen.y)
    }
}
