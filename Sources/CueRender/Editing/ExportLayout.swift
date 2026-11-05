import CoreGraphics
import Foundation

/// One slide as editable parts, read from the rendered page by
/// `92-export.js`. Boxes and sizes are in the slide's design-canvas pixels
/// (e.g. of 1920 × 1080), with the origin at its top left.
public struct ExportLayout: Sendable, Equatable, Decodable {
    public struct Box: Sendable, Equatable, Decodable {
        public let x, y, width, height: Double
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
    }

    public struct Image: Sendable, Equatable, Decodable {
        public let box: Box
        /// `data:` or a `cue-deck:` URL.
        public let source: String
        public let naturalWidth, naturalHeight: Double
        /// CSS object-fit: fill, cover, contain, none, scale-down.
        public let fit: String
        public let opacity: Double
    }

    /// Where the canvas is in the page, in CSS pixels (for snapshots).
    public let canvas: Box
    public let width, height: Double
    public let texts: [TextBox]
    public let images: [Image]
}
