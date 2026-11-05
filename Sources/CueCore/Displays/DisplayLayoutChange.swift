import Foundation

/// What the show must do to its windows when roles or screens change.
/// Computed here so hot-plug handling is testable without AppKit.
public struct DisplayLayoutChange: Sendable, Equatable {
    /// Screens whose window must close (unplugged, or changing role).
    public var close: [String]
    /// Screens that need a new window, with its role. Off screens get one
    /// too: a black cover, so the desktop never shows during the show.
    public var open: [String: DisplayRole]

    public var isEmpty: Bool { close.isEmpty && open.isEmpty }

    /// `current` is what has a window now; `next` is what should.
    public init(from current: [String: DisplayRole], to next: DisplayRoles) {
        var close: [String] = []
        var open: [String: DisplayRole] = [:]
        for (id, role) in current where next.roles[id] != role { // Unplugged screens have no role at all.
            close.append(id)
        }
        for (id, role) in next.roles where current[id] != role {
            open[id] = role
        }
        self.close = close.sorted()
        self.open = open
    }
}
