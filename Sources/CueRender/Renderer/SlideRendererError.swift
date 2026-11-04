import Foundation

public enum SlideRendererError: Error, Equatable {
    /// The page hasn't finished loading and configuring the player yet.
    case notReady
}
