import Foundation

/// Reads design sizes declared in the various deck formats.
enum CanvasParsing {
    /// `<meta name="cue:canvas" content="1920x1080">`, else the hz:* pair.
    static func cueCanvas(_ root: HTMLNode) -> CanvasSize? {
        if let value = root.meta(named: "cue:canvas"), let size = parse(pair: value) { return size }
        return hzCanvas(root)
    }

    /// `<meta name="hz:canvas-width">` and `hz:canvas-height`.
    static func hzCanvas(_ root: HTMLNode) -> CanvasSize? {
        guard let width = root.meta(named: "hz:canvas-width").flatMap(Double.init),
              let height = root.meta(named: "hz:canvas-height").flatMap(Double.init),
              width > 0, height > 0
        else { return nil }
        return CanvasSize(width: width, height: height)
    }

    /// "1920x1080", "1920×1080" or "1920 1080".
    static func parse(pair: String) -> CanvasSize? {
        let numbers = pair.split(whereSeparator: { !$0.isNumber && $0 != "." }).compactMap { Double($0) }
        guard numbers.count == 2, numbers[0] > 0, numbers[1] > 0 else { return nil }
        return CanvasSize(width: numbers[0], height: numbers[1])
    }

    /// Width and height from an SVG `viewBox="0 0 1280 720"`.
    static func viewBox(_ value: String?) -> CanvasSize? {
        guard let value else { return nil }
        let numbers = value.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        guard numbers.count == 4, numbers[2] > 0, numbers[3] > 0 else { return nil }
        return CanvasSize(width: numbers[2], height: numbers[3])
    }
}
