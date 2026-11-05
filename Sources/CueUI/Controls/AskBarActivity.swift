import Foundation

/// What the agent behind the Ask bar is doing; the bar's glow shows it.
/// Still when nobody is connected, slow while listening, quick while
/// working, quickest (with a shimmer) while it edits the slide.
public enum AskBarActivity: Sendable, Equatable {
    case offline, idle, listening, working, editing

    /// Glow turns per design period.
    var glowSpeed: Double {
        switch self {
        case .offline, .idle: 1
        case .listening: 1
        case .working: 2.5
        case .editing: 5
        }
    }

    /// Nothing is happening: hold the glow still (also saves battery).
    var glowIsStill: Bool { self == .offline || self == .idle }

    var haloOpacity: Double {
        switch self {
        case .offline: 0.22
        case .idle: 0.4
        case .listening: 0.55
        case .working: 0.7
        case .editing: 0.9
        }
    }

    var shimmers: Bool { self == .editing }
}
