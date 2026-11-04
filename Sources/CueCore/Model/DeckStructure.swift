import Foundation

/// What an adapter found in a deck's HTML. This is the contract between
/// slide detection (CueCore) and rendering (CueRender).
public struct DeckStructure: Sendable, Equatable, Codable {
    /// Which adapter recognised the deck.
    public var adapter: AdapterKind
    /// How Cue drives the deck. See `RenderMode`.
    public var renderMode: RenderMode
    /// The design size of one slide, in CSS pixels.
    public var canvas: CanvasSize
    /// A CSS selector whose `querySelectorAll` result, in document order,
    /// is exactly `slides`. CueBridge uses it to find slide elements.
    public var slideSelector: String
    public var slides: [SlideInfo]
    /// Character range of a deck's own player script that Cue's universal
    /// player replaces when serving the page. Never removed on disk.
    public var replacedPlayerScript: SourceRange?

    public init(
        adapter: AdapterKind,
        renderMode: RenderMode,
        canvas: CanvasSize,
        slideSelector: String,
        slides: [SlideInfo],
        replacedPlayerScript: SourceRange? = nil
    ) {
        self.adapter = adapter
        self.renderMode = renderMode
        self.canvas = canvas
        self.slideSelector = slideSelector
        self.slides = slides
        self.replacedPlayerScript = replacedPlayerScript
    }
}

public enum AdapterKind: String, Sendable, Codable, CaseIterable {
    case cue            // data-cue-slide, data-cue-build, data-cue-notes
    case claudeDesign   // hz:* meta tags, data-speaker-notes, deck-motion JSON
    case reveal         // .reveal .slides > section
    case documentRole   // data-document-role="page" / aria-roledescription="slide"
    case fallback       // top-level sections, or the whole page
}

public enum RenderMode: String, Sendable, Codable {
    /// Cue's universal player owns visibility, scaling, builds and embeds.
    case cueDriven
    /// The deck's own script runs untouched; Cue forwards keys to it.
    case passthrough
}

public struct CanvasSize: Sendable, Equatable, Codable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
    public static let hd = CanvasSize(width: 1920, height: 1080)
}
