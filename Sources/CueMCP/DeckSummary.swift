import Foundation

/// A deck Cue has open, or opened recently, as Claude sees it in list_decks.
public struct DeckSummary: Sendable, Codable, Equatable {
    public var path: String
    public var title: String
    /// Nil for a recent deck that isn't open.
    public var slides: Int?
    public var isOpen: Bool
    /// The deck Cue's tools work on.
    public var isTarget: Bool
    public var hasUnsavedChanges: Bool

    public init(path: String, title: String, slides: Int?, isOpen: Bool, isTarget: Bool, hasUnsavedChanges: Bool) {
        self.path = path
        self.title = title
        self.slides = slides
        self.isOpen = isOpen
        self.isTarget = isTarget
        self.hasUnsavedChanges = hasUnsavedChanges
    }

    enum CodingKeys: String, CodingKey {
        case path, title, slides
        case isOpen = "open"
        case isTarget = "target"
        case hasUnsavedChanges = "unsaved_changes"
    }
}
