import AppKit
import CueCore

extension ShowWindow {
    /// A borderless window covering `screen`, for presenting `role`.
    static func covering(_ screen: NSScreen, for role: DisplayRole) -> ShowWindow {
        let window = ShowWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.collectionBehavior = [.fullScreenNone, .canJoinAllSpaces]
        window.level = level(for: role)
        return window.configured()
    }

    /// Screens the audience (or nobody) looks at sit above ordinary windows,
    /// so another app or a dialog can't appear on the projector. The
    /// presenter's own screen stays normal, so other apps can be reached.
    static func level(for role: DisplayRole) -> NSWindow.Level {
        role == .presenter ? .normal : .statusBar
    }

    private func configured() -> ShowWindow {
        backgroundColor = .black
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        return self
    }
}
