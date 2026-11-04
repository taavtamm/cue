import Foundation

/// How well the live DOM lined up with the deck's source.
public struct LiveMappingReport: Sendable, Equatable {
    /// Elements that got a `data-cue-id`.
    public let mapped: Int
    /// Live elements with no source: added by the deck's own scripts.
    public let unmapped: Int
    /// Source elements not found in the live page: removed by deck scripts.
    public let missing: Int
    /// The DOM matched the source one-to-one.
    public let exact: Bool

    init(_ object: Any?) {
        let values = object as? [String: Any] ?? [:]
        mapped = values["mapped"] as? Int ?? 0
        unmapped = values["unmapped"] as? Int ?? 0
        missing = values["missing"] as? Int ?? 0
        exact = values["exact"] as? Bool ?? false
    }
}

/// The source element under a point, with its box in the surface.
public struct LiveHit: Sendable, Equatable {
    public let cueID: String
    public let tag: String
    /// In the surface's coordinates (points, origin bottom-left like AppKit).
    public let frame: CGRect
}
