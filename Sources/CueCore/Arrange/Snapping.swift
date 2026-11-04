import CoreGraphics
import Foundation

/// Snaps a box being moved or resized to the slide's edges and centre, and
/// to other boxes' edges and centres, and says which guide lines to draw.
/// Everything is in design-canvas pixels.
public struct Snapping: Sendable {
    public struct Guide: Sendable, Equatable {
        public enum Axis: Sendable { case vertical, horizontal }
        public let axis: Axis
        /// x for a vertical guide, y for a horizontal one.
        public let position: CGFloat
    }

    public let canvas: CGSize
    public let others: [CGRect]
    /// How close an edge must come to snap, in canvas pixels.
    public var threshold: CGFloat

    public init(canvas: CGSize, others: [CGRect], threshold: CGFloat = 8) {
        self.canvas = canvas
        self.others = others
        self.threshold = threshold
    }

    /// Lines a box can snap to, per axis.
    var verticalLines: [CGFloat] { [0, canvas.width / 2, canvas.width] + others.flatMap { [$0.minX, $0.midX, $0.maxX] } }
    var horizontalLines: [CGFloat] { [0, canvas.height / 2, canvas.height] + others.flatMap { [$0.minY, $0.midY, $0.maxY] } }

    /// A moved box shifted onto the nearest lines (its left, centre or right;
    /// top, middle or bottom), and the guides that caused it.
    public func snap(moving frame: CGRect) -> (frame: CGRect, guides: [Guide]) {
        let x = nearest([frame.minX, frame.midX, frame.maxX], to: verticalLines)
        let y = nearest([frame.minY, frame.midY, frame.maxY], to: horizontalLines)
        var guides: [Guide] = []
        if let x { guides.append(Guide(axis: .vertical, position: x.line)) }
        if let y { guides.append(Guide(axis: .horizontal, position: y.line)) }
        return (frame.offsetBy(dx: x?.shift ?? 0, dy: y?.shift ?? 0), guides)
    }

    /// A resized box with the dragged edges snapped.
    public func snap(resizing frame: CGRect, handle: ElementPlacement.Handle) -> (frame: CGRect, guides: [Guide]) {
        var result = frame
        var guides: [Guide] = []
        if handle.contains(.left), let x = nearest([frame.minX], to: verticalLines) {
            result = CGRect(x: frame.minX + x.shift, y: result.minY, width: frame.width - x.shift, height: result.height)
            guides.append(Guide(axis: .vertical, position: x.line))
        }
        if handle.contains(.right), let x = nearest([frame.maxX], to: verticalLines) {
            result.size.width += x.shift
            guides.append(Guide(axis: .vertical, position: x.line))
        }
        if handle.contains(.top), let y = nearest([frame.minY], to: horizontalLines) {
            result = CGRect(x: result.minX, y: frame.minY + y.shift, width: result.width, height: frame.height - y.shift)
            guides.append(Guide(axis: .horizontal, position: y.line))
        }
        if handle.contains(.bottom), let y = nearest([frame.maxY], to: horizontalLines) {
            result.size.height += y.shift
            guides.append(Guide(axis: .horizontal, position: y.line))
        }
        return (result, guides)
    }

    /// The smallest shift (within the threshold) that lands one of `edges` on a line.
    private func nearest(_ edges: [CGFloat], to lines: [CGFloat]) -> (shift: CGFloat, line: CGFloat)? {
        var best: (shift: CGFloat, line: CGFloat)?
        for edge in edges {
            for line in lines where abs(line - edge) <= threshold {
                if best == nil || abs(line - edge) < abs(best!.shift) { best = (line - edge, line) }
            }
        }
        return best
    }
}
