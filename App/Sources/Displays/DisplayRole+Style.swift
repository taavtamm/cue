import CueCore
import CueUI
import SwiftUI

extension DisplayRole {
    /// Badge and dot colour, from the Displays design.
    var color: Color {
        switch self {
        case .stage: CueTheme.destructive
        case .presenter: CueTheme.selection
        case .confidence: CueTheme.violet
        case .mirror: CueTheme.live
        case .off: Color.white.opacity(0.35)
        }
    }

    /// A symbol drawn on the screen tile in the arrangement.
    var symbol: String {
        switch self {
        case .stage: "play.rectangle.fill"
        case .presenter: "rectangle.split.2x1.fill"
        case .confidence: "timer"
        case .mirror: "rectangle.on.rectangle"
        case .off: "moon.zzz"
        }
    }
}
