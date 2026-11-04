import CoreGraphics
import Foundation

/// Turns a move or resize on the slide into inline style changes, without
/// touching the deck's own layout.
///
/// - Elements Cue inserted (`data-cue-element`) are absolutely positioned:
///   their `left`, `top`, `width` and `height` change.
/// - The deck's own elements keep their place in its layout and get an inline
///   `translate:` offset; a resize sets inline `width` and `height`.
///
/// Frames are in the slide's design-canvas pixels (e.g. of 1920 × 1080).
public enum ElementPlacement {
    /// Whole canvas pixels: decks stay readable and diffs stay small.
    static func px(_ value: CGFloat) -> String { "\(Int(value.rounded()))px" }

    public static func changes(
        from old: CGRect, to new: CGRect, inlineStyle: String, isCueElement: Bool
    ) -> [StyleChange] {
        let dx = new.minX - old.minX, dy = new.minY - old.minY
        let resized = abs(new.width - old.width) >= 0.5 || abs(new.height - old.height) >= 0.5
        var changes: [StyleChange] = []
        if isCueElement {
            let style = InlineStyle(inlineStyle)
            let left = style.pixels("left") ?? old.minX, top = style.pixels("top") ?? old.minY
            if abs(dx) >= 0.5 { changes.append(StyleChange("left", px(left + dx))) }
            if abs(dy) >= 0.5 { changes.append(StyleChange("top", px(top + dy))) }
        } else if abs(dx) >= 0.5 || abs(dy) >= 0.5 {
            let (tx, ty) = InlineStyle(inlineStyle).translate
            let x = tx + dx, y = ty + dy
            let value = abs(x) < 0.5 && abs(y) < 0.5 ? nil : "\(px(x)) \(px(y))"
            changes.append(StyleChange("translate", value))
        }
        if resized {
            changes.append(StyleChange("width", px(new.width)))
            changes.append(StyleChange("height", px(new.height)))
        }
        return changes
    }

    /// A frame moved by `delta`, optionally locked to the larger axis (Shift).
    public static func moved(_ frame: CGRect, by delta: CGSize, constrained: Bool) -> CGRect {
        var delta = delta
        if constrained { abs(delta.width) >= abs(delta.height) ? (delta.height = 0) : (delta.width = 0) }
        return frame.offsetBy(dx: delta.width, dy: delta.height)
    }

    /// Which corner or edge a resize drags.
    public struct Handle: OptionSet, Sendable, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let left = Handle(rawValue: 1), right = Handle(rawValue: 2)
        public static let top = Handle(rawValue: 4), bottom = Handle(rawValue: 8)
    }

    /// A frame resized by dragging `handle` by `delta` (top-left origin, so
    /// +y is down). Shift keeps the aspect ratio. Never smaller than 8 px.
    public static func resized(_ frame: CGRect, handle: Handle, by delta: CGSize, keepAspect: Bool) -> CGRect {
        var minX = frame.minX, maxX = frame.maxX, minY = frame.minY, maxY = frame.maxY
        if handle.contains(.left) { minX = min(frame.maxX - 8, frame.minX + delta.width) }
        if handle.contains(.right) { maxX = max(frame.minX + 8, frame.maxX + delta.width) }
        if handle.contains(.top) { minY = min(frame.maxY - 8, frame.minY + delta.height) }
        if handle.contains(.bottom) { maxY = max(frame.minY + 8, frame.maxY + delta.height) }
        var result = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        if keepAspect, frame.height > 0 {
            let ratio = frame.width / frame.height
            let height = result.width / ratio
            if handle.contains(.top) { result.origin.y = result.maxY - height }
            result.size.height = height
        }
        return result
    }
}
