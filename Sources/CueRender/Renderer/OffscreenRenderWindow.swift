import AppKit

/// A window that holds a renderer nobody should see (sidebar thumbnails).
/// WebKit only draws pages that are in an ordered-in window, so the window
/// stays ordered in, parked far outside every screen.
///
/// macOS moves windows back onto a screen after display or Space changes,
/// which once left a stray slide on the desktop. This window refuses to be
/// constrained onto a screen, and parks itself again if anything moves it.
@MainActor
public final class OffscreenRenderWindow: NSWindow {
    /// Far outside any real display arrangement.
    static let parkedOrigin = CGPoint(x: -30_000, y: -30_000)

    public init(size: CGSize) {
        super.init(
            contentRect: CGRect(origin: Self.parkedOrigin, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        isExcludedFromWindowsMenu = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hasShadow = false
        collectionBehavior = [.transient, .ignoresCycle, .stationary, .fullScreenNone]
        NotificationCenter.default.addObserver(
            self, selector: #selector(park), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NotificationCenter.default.addObserver(self, selector: #selector(park), name: NSWindow.didMoveNotification, object: self)
        NotificationCenter.default.addObserver(
            self, selector: #selector(park), name: NSWindow.didChangeScreenNotification, object: self
        )
    }

    /// Never let AppKit pull the frame onto a screen.
    override public func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }

    /// Moves back off screen if the system (or anything else) moved it.
    @objc func park() {
        guard frame.origin != Self.parkedOrigin else { return }
        setFrameOrigin(Self.parkedOrigin)
    }

    /// True when no part of the window overlaps any screen.
    public var isOffAllScreens: Bool {
        NSScreen.screens.allSatisfy { !$0.frame.intersects(frame) }
    }
}
