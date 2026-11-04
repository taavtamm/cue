import CoreGraphics
import Foundation

/// Markup for things the user inserts: text boxes, images and shapes. Each is
/// absolutely positioned on the slide's design canvas and marked
/// `data-cue-element`, with a fresh id, so it reads clearly in the HTML.
public enum ElementTemplate: Sendable, Equatable {
    case textBox(text: String, fontSize: Int, fontFamily: String?)
    /// `source` is a `data:` URI (images are embedded in the deck).
    case image(source: String, description: String)
    case shape(Shape)

    public enum Shape: String, Sendable, CaseIterable {
        case rectangle, roundedRectangle, ellipse, line, arrow

        public var title: String {
            switch self {
            case .rectangle: "Rectangle"
            case .roundedRectangle: "Rounded Rectangle"
            case .ellipse: "Ellipse"
            case .line: "Line"
            case .arrow: "Arrow"
            }
        }
    }

    /// A good starting size on a canvas, centred unless a frame is given.
    public func defaultFrame(on canvas: CGSize, imageSize: CGSize? = nil) -> CGRect {
        let size: CGSize
        switch self {
        case .textBox: size = CGSize(width: canvas.width * 0.4, height: canvas.height * 0.12)
        case .image:
            let natural = imageSize ?? CGSize(width: canvas.width / 2, height: canvas.height / 2)
            let scale = min(1, canvas.width * 0.6 / max(1, natural.width), canvas.height * 0.6 / max(1, natural.height))
            size = CGSize(width: natural.width * scale, height: natural.height * scale)
        case .shape(.line), .shape(.arrow): size = CGSize(width: canvas.width * 0.25, height: 24)
        case .shape: size = CGSize(width: canvas.width * 0.2, height: canvas.width * 0.2)
        }
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// The element's HTML. `id` should be unique in the deck.
    public func html(id: String, frame: CGRect) -> String {
        let place = "position: absolute; left: \(px(frame.minX)); top: \(px(frame.minY)); "
            + "width: \(px(frame.width)); height: \(px(frame.height));"
        switch self {
        case .textBox(let text, let fontSize, let family):
            let font = family.map { " font-family: \(Self.cssFamily($0));" } ?? ""
            let style = place + " font-size: \(fontSize)px; line-height: 1.2;\(font)"
            return #"<div data-cue-element="text" id="\#(id)" style="\#(style)">\#(Self.escape(text))</div>"#
        case .image(let source, let description):
            let style = place + " object-fit: contain;"
            let alt = Self.escape(description)
            return #"<img data-cue-element="image" id="\#(id)" src="\#(source)" alt="\#(alt)" style="\#(style)">"#
        case .shape(let shape):
            return Self.shapeHTML(shape, id: id, place: place, frame: frame)
        }
    }

    private static func shapeHTML(_ shape: Shape, id: String, place: String, frame: CGRect) -> String {
        let open = #"<div data-cue-element="shape" data-cue-shape="\#(shape.rawValue)" id="\#(id)""#
        switch shape {
        case .rectangle:
            return open + #" style="\#(place) background: #2f7bff;"></div>"#
        case .roundedRectangle:
            return open + #" style="\#(place) background: #2f7bff; border-radius: 24px;"></div>"#
        case .ellipse:
            return open + #" style="\#(place) background: #2f7bff; border-radius: 50%;"></div>"#
        case .line, .arrow:
            let head = shape == .arrow
                ? #"<path d="M 86 2 L 98 12 L 86 22" fill="none" stroke="currentColor" stroke-width="4"/>"#
                : ""
            let svg = #"<svg viewBox="0 0 100 24" preserveAspectRatio="none" width="100%" height="100%">"#
                + #"<line x1="0" y1="12" x2="98" y2="12" stroke="currentColor" stroke-width="4"/>\#(head)</svg>"#
            return open + #" style="\#(place) color: #2f7bff;">\#(svg)</div>"#
        }
    }

    private func px(_ value: CGFloat) -> String { ElementPlacement.px(value) }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static func cssFamily(_ family: String) -> String {
        family.contains(" ") ? "'\(family.replacingOccurrences(of: "'", with: ""))'" : family
    }

    /// A short id that won't clash with ids already in the source.
    public static func uniqueID(prefix: String, in source: String) -> String {
        for _ in 0..<64 {
            let candidate = "\(prefix)-\(UUID().uuidString.prefix(6).lowercased())"
            if !source.contains("id=\"\(candidate)\"") { return candidate }
        }
        return "\(prefix)-\(UUID().uuidString.lowercased())"
    }
}
