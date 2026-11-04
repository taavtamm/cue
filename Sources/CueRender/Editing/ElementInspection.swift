import CoreGraphics
import Foundation

/// How a selected element looks and where it is, for the inspector and the
/// selection box.
public struct ElementInspection: Sendable, Equatable {
    /// In the surface's coordinates (points, origin bottom-left like AppKit).
    public let frame: CGRect
    /// On the slide's design canvas, in canvas pixels (e.g. of 1920 × 1080).
    public let canvasFrame: CGRect
    /// Computed values: font-family, font-weight, font-size, line-height,
    /// letter-spacing, color, text-align.
    public let computedStyle: [String: String]
    /// The build step (0-based) that reveals this element, if any.
    public let buildStep: Int?
    /// No child elements, so its text can be edited directly.
    public let isLeaf: Bool
    /// Holds a running live web embed.
    public let hostsEmbed: Bool

    public init(
        frame: CGRect, canvasFrame: CGRect, computedStyle: [String: String], buildStep: Int?, isLeaf: Bool,
        hostsEmbed: Bool = false
    ) {
        self.frame = frame
        self.canvasFrame = canvasFrame
        self.computedStyle = computedStyle
        self.buildStep = buildStep
        self.isLeaf = isLeaf
        self.hostsEmbed = hostsEmbed
    }
}

/// The animations running on one slide, read from `document.getAnimations()`.
public struct SlideAnimations: Sendable, Equatable {
    public struct Track: Sendable, Equatable {
        /// The CSS animation name, transitioned property, or "animation".
        public let name: String
        /// A short description of the animated element.
        public let target: String
        public let delay: TimeInterval
        public let duration: TimeInterval
        /// -1 means it loops forever.
        public let iterations: Double
        public let easing: String

        public init(name: String, target: String, delay: TimeInterval, duration: TimeInterval,
                    iterations: Double, easing: String) {
            self.name = name
            self.target = target
            self.delay = delay
            self.duration = duration
            self.iterations = iterations
            self.easing = easing
        }

        public var loops: Bool { iterations < 0 }
    }

    public let tracks: [Track]
    /// Live web embeds on the slide. They animate inside their own sandboxed
    /// frame, so their animations can't be listed, only shown as running.
    public let embedCount: Int

    public init(tracks: [Track], embedCount: Int) {
        self.tracks = tracks
        self.embedCount = embedCount
    }
}
