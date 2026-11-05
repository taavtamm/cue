import Foundation

/// What one screen shows during the show.
public enum DisplayRole: String, Sendable, Codable, CaseIterable, Identifiable {
    /// The audience sees the live slide. Only one screen at a time.
    case stage
    /// Current and next slide, notes, timer and controls.
    case presenter
    /// Large next slide and timer, for a floor or lectern screen.
    case confidence
    /// A second audience screen, kept in step with the stage.
    case mirror
    /// Black for the whole show, so the desktop and other windows stay hidden.
    /// (macOS has no public way for an app to switch one screen off.)
    case off

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .stage: "Stage"
        case .presenter: "Presenter view"
        case .confidence: "Confidence monitor"
        case .mirror: "Mirror stage"
        case .off: "Off"
        }
    }

    public var summary: String {
        switch self {
        case .stage: "The audience sees the live slide, animations and embeds."
        case .presenter: "Current and next slide, notes, timer and controls."
        case .confidence: "Large next slide and timer for a floor or lectern screen."
        case .mirror: "A second audience screen, kept in step with the stage."
        case .off: "Stays black during the show, so your desktop and other windows stay hidden."
        }
    }

    /// Audience-facing roles show the slide itself.
    public var isAudience: Bool { self == .stage || self == .mirror }
}
