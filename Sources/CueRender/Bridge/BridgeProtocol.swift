import CueCore
import Foundation

// The wire protocol between Swift and CueBridge.js. CueBridge runs in an
// isolated WKContentWorld named `CueBridge.worldName`; deck scripts can't
// see it. The JS side mirrors these names exactly (see Resources/JS/bridge/).

public enum CueBridge {
    public static let worldName = "cue-bridge"
    /// The one script message handler, registered only in the bridge world.
    public static let handlerName = "cue"
}

/// Swift → JS. Sent as `window.__cue.receive(<json>)` in the bridge world.
public enum BridgeCommand: Sendable, Equatable, Codable {
    /// Sent once after load. Tells the player how to find and drive slides.
    case configure(PlayerConfig)
    /// Show this slide and build. `finished` renders the slide's final state
    /// with builds complete and no entry animation (next-slide preview, PDF).
    case show(ShowPosition, finished: Bool)
    case setBlack(Bool)
    case setWhite(Bool)
    /// Pause or resume Web Animations, media and timers where possible.
    case setPaused(Bool)
    /// Line this surface's slide animations up with another surface's clock,
    /// so mirrored screens show the same frame. See `AnimationClock`.
    case alignAnimations(AnimationClock)
}

public struct PlayerConfig: Sendable, Equatable, Codable {
    public var renderMode: RenderMode
    public var slideSelector: String
    public var canvas: CanvasSize
    /// Build counts per slide, so the player can bound `show`.
    public var buildCounts: [Int]
    /// Surface role, so e.g. thumbnails never start embeds.
    public var surface: SurfaceKind
    /// Per slide, per build step: selectors of the elements that step reveals.
    /// Used by the generic player. Claude Design decks use their own JSON.
    public var buildTargets: [[[String]]]

    public init(structure: DeckStructure, surface: SurfaceKind) {
        renderMode = structure.renderMode
        slideSelector = structure.slideSelector
        canvas = structure.canvas
        buildCounts = structure.slides.map(\.builds.count)
        buildTargets = structure.slides.map { $0.builds.map(\.targets) }
        self.surface = surface
    }
}

public enum SurfaceKind: String, Sendable, Codable {
    /// `mirror` is a second audience screen: it animates like the stage but
    /// leaves auto-builds to the stage, so each step is requested once.
    case stage, mirror, presenterCurrent, nextPreview, editor, thumbnail, export
}

/// JS → Swift. Posted by CueBridge to `CueBridge.handlerName`.
public enum BridgeEvent: Sendable, Equatable, Codable {
    /// Player is configured and found this many slides.
    case ready(slideCount: Int)
    /// The slide the page is showing. In passthrough mode this comes from
    /// the deck's own script, so ShowController follows it.
    case position(ShowPosition)
    /// Live content found per slide index (embeds, video, canvas, rAF).
    case liveContent(slides: [Int])
    /// Inline text editing on an editor surface (see 89-inline-text.js).
    case textEditing(InlineTextEvent)
    case error(message: String)
}
