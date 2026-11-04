import Foundation

public struct SlideInfo: Sendable, Equatable, Codable, Identifiable {
    /// The element's `id`, or a stable generated one ("slide-3").
    public var id: String
    public var label: String
    public var notes: String
    /// Child-index path from the document root to the slide element.
    /// Used by the source editor to map back to the file.
    public var elementPath: ElementPath
    /// Character range of the slide element in the source file.
    public var sourceRange: SourceRange?
    /// Build steps after the initial state. Empty means one state.
    public var builds: [BuildStep]
    /// True when the slide holds content that animates on its own
    /// (web embeds, video, canvas, scripted animation). Drives the LIVE tag.
    public var hasLiveContent: Bool

    public init(
        id: String,
        label: String,
        notes: String = "",
        elementPath: ElementPath,
        sourceRange: SourceRange? = nil,
        builds: [BuildStep] = [],
        hasLiveContent: Bool = false
    ) {
        self.id = id
        self.label = label
        self.notes = notes
        self.elementPath = elementPath
        self.sourceRange = sourceRange
        self.builds = builds
        self.hasLiveContent = hasLiveContent
    }

    /// Number of states this slide steps through (initial + builds).
    public var stateCount: Int { builds.count + 1 }
}

public struct BuildStep: Sendable, Equatable, Codable {
    /// CSS selectors of the elements this step reveals or hides.
    public var targets: [String]
    /// Effect name, e.g. "fade", "rise". Nil means appear.
    public var effect: String?
    public init(targets: [String], effect: String? = nil) {
        self.targets = targets
        self.effect = effect
    }
}

/// Child-element indices from `<html>` down. `[1, 0, 3]` = html > 2nd child > 1st > 4th.
public typealias ElementPath = [Int]

/// A half-open range of UTF-16 code unit offsets into the source text,
/// matching parse5's `sourceCodeLocationInfo` offsets.
public struct SourceRange: Sendable, Equatable, Codable, Hashable {
    public var start: Int
    public var end: Int
    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
    public var length: Int { end - start }
}
