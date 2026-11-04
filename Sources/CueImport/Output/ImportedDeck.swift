import CueCore
import Foundation

/// A converted presentation, before it is written as HTML. Positions are CSS
/// pixels on the slide canvas.
public struct ImportedDeck: Sendable {
    public var title: String
    public var canvas: CanvasSize
    public var slides: [ImportedSlide]
    /// True when slides are pictures (PDF pages, Keynote previews): only notes can be edited.
    public var isPresentOnly = false

    public init(title: String, canvas: CanvasSize, slides: [ImportedSlide] = []) {
        self.title = title
        self.canvas = canvas
        self.slides = slides
    }
}

public struct ImportedSlide: Sendable {
    public var label: String
    public var notes: String
    /// A CSS `background` value, e.g. `#fff` or `url(…) center / cover`.
    public var background: String?
    public var elements: [ImportedElement]

    public init(label: String = "", notes: String = "", background: String? = nil, elements: [ImportedElement] = []) {
        self.label = label
        self.notes = notes
        self.background = background
        self.elements = elements
    }
}

/// One positioned thing on a slide.
public struct ImportedElement: Sendable {
    public enum Content: Sendable {
        case empty
        /// Already-escaped inner HTML (styled text, a table, inline SVG).
        case html(String)
        /// A picture from the asset store, optionally cropped.
        case image(source: String, crop: ImageCrop?, alt: String)
        case group([ImportedElement])
    }

    public var name: String
    public var frame: Rect
    public var rotation: Double = 0
    public var flipH = false
    public var flipV = false
    /// Extra CSS for the element's box: fill, border, radius, text layout.
    public var style = CSSStyle()
    public var content: Content
    /// Text boxes get flex layout so vertical anchoring works.
    public var isTextBox = false
    /// Build step (1-based) and effect name, from the source's click sequence.
    public var build: (step: Int, effect: String)?

    public init(name: String, frame: Rect, content: Content) {
        self.name = name
        self.frame = frame
        self.content = content
    }
}

public struct Rect: Sendable, Equatable {
    public var x, y, width, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Fractions trimmed from each side of a picture (0…1).
public struct ImageCrop: Sendable, Equatable {
    public var left, top, right, bottom: Double
    public var isEmpty: Bool { left == 0 && top == 0 && right == 0 && bottom == 0 }
}
