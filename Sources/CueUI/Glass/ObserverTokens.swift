import Foundation

/// Block-based notification observers that are removed when this object
/// goes away. Attach it to whatever the observers serve (a window) so they
/// live exactly as long.
final class ObserverTokens {
    private let tokens: [any NSObjectProtocol]

    init(_ tokens: [any NSObjectProtocol]) {
        self.tokens = tokens
    }

    deinit {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
    }
}
