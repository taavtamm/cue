import CoreGraphics
import Foundation

/// Where a slide's design canvas sits in a surface, and its scale, so points
/// and boxes convert between the surface (AppKit points, origin bottom-left)
/// and the canvas (design pixels, origin top-left).
public struct CanvasGeometry: Sendable, Equatable {
    /// The canvas's box in the surface's coordinates.
    public let frame: CGRect
    /// Surface points per canvas pixel.
    public let scale: CGFloat

    public init(frame: CGRect, scale: CGFloat) {
        self.frame = frame
        self.scale = scale
    }

    public func canvasRect(fromView rect: CGRect) -> CGRect {
        CGRect(x: (rect.minX - frame.minX) / scale, y: (frame.maxY - rect.maxY) / scale,
               width: rect.width / scale, height: rect.height / scale)
    }

    public func viewRect(fromCanvas rect: CGRect) -> CGRect {
        CGRect(x: frame.minX + rect.minX * scale, y: frame.maxY - rect.maxY * scale,
               width: rect.width * scale, height: rect.height * scale)
    }

    public func canvasPoint(fromView point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - frame.minX) / scale, y: (frame.maxY - point.y) / scale)
    }

    /// A drag in surface points as a canvas delta (+y down).
    public func canvasDelta(fromView delta: CGSize) -> CGSize {
        CGSize(width: delta.width / scale, height: -delta.height / scale)
    }
}
