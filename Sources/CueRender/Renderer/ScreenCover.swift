import AppKit

/// Black or white screen, drawn natively over the web view so no deck
/// script can see or undo it.
enum ScreenCover: Equatable {
    case none, black, white

    var color: NSColor? {
        switch self {
        case .none: nil
        case .black: .black
        case .white: .white
        }
    }
}
