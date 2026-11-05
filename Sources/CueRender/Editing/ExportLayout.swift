import CoreGraphics
import Foundation

/// One slide as editable parts, read from the rendered page by
/// `92-export.js`. Boxes and sizes are in the slide's design-canvas pixels
/// (e.g. of 1920 × 1080), with the origin at its top left.
public struct ExportLayout: Sendable, Equatable, Decodable {
    public struct Box: Sendable, Equatable, Decodable {
        public let x, y, width, height: Double
        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    }

    /// A styled stretch of text.
    public struct Run: Sendable, Equatable, Decodable {
        public let text: String
        public let family: String
        /// sans-serif, serif or monospace: from the CSS font stack.
        public let generic: String?
        public let weight: Int
        public let italic: Bool
        public let underline: Bool
        /// CSS pixels.
        public let size: Double
        /// A CSS colour as computed: `rgb(…)` or `rgba(…)`.
        public let color: String
        public let letterSpacing: Double
    }

    public struct TextBox: Sendable, Equatable, Decodable {
        public let box: Box
        /// Paragraphs (split at line breaks), each a list of runs.
        public let paragraphs: [[Run]]
        /// left, center, right or justify.
        public let align: String
        /// CSS pixels.
        public let lineHeight: Double
        /// It runs over more than one line, so it should wrap at its width.
        public let wraps: Bool
        /// Paint order among the slide's texts, pictures and shapes.
        public var order: Int?
    }

    public struct Image: Sendable, Equatable, Decodable {
        public let box: Box
        /// `data:` or a `cue-deck:` URL.
        public let source: String
        public let naturalWidth, naturalHeight: Double
        /// CSS object-fit: fill, cover, contain, none, scale-down.
        public let fit: String
        public let opacity: Double
        public var order: Int?
    }

    /// Where the canvas is in the page, in CSS pixels (for snapshots).
    public let canvas: Box
    public let width, height: Double
    public let texts: [TextBox]
    public let images: [Image]
    /// Boxes PowerPoint draws itself, from `93-export-shapes.js`.
    public var shapes: [Shape] = []
    /// The slide's flat fill, or nil when only the picture can show it.
    public var background: Fill?
    /// Elements only a picture can show (radial gradients, SVG, embeds…).
    public var unsupported = 0
    /// Shapes kept in the picture because something there paints over them.
    public var keptShapes = 0
    /// Something on the slide needs the flattened picture.
    public var needsPicture = true

    enum CodingKeys: String, CodingKey {
        case canvas, width, height, texts, images, shapes, background, unsupported, keptShapes, needsPicture
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        canvas = try c.decode(Box.self, forKey: .canvas)
        width = try c.decode(Double.self, forKey: .width)
        height = try c.decode(Double.self, forKey: .height)
        texts = try c.decode([TextBox].self, forKey: .texts)
        images = try c.decode([Image].self, forKey: .images)
        shapes = try c.decodeIfPresent([Shape].self, forKey: .shapes) ?? []
        background = try c.decodeIfPresent(Fill.self, forKey: .background)
        unsupported = try c.decodeIfPresent(Int.self, forKey: .unsupported) ?? 0
        keptShapes = try c.decodeIfPresent(Int.self, forKey: .keptShapes) ?? 0
        needsPicture = try c.decodeIfPresent(Bool.self, forKey: .needsPicture) ?? true
    }
}
