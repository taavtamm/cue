import AppKit

/// Where a window opens: centred in a screen's visible area (inside the
/// menu bar and Dock), and never bigger than that area, so it can't open
/// partly off a small screen.
public enum WindowPlacement {
    /// `size` centred in `visibleFrame`, clamped to it and to `minimum`
    /// (the minimum wins only when it still fits).
    public static func centred(
        _ size: CGSize, in visibleFrame: CGRect, minimum: CGSize = .zero, margin: CGFloat = 20
    ) -> CGRect {
        let inset = (x: min(margin, visibleFrame.width / 4), y: min(margin, visibleFrame.height / 4))
        let room = visibleFrame.insetBy(dx: inset.x, dy: inset.y)
        let width = min(max(size.width, minimum.width), room.width)
        let height = min(max(size.height, minimum.height), room.height)
        return CGRect(
            x: (visibleFrame.midX - width / 2).rounded(),
            y: (visibleFrame.midY - height / 2).rounded(),
            width: width, height: height
        )
    }

    /// The screen to open on: the key window's, else the main screen.
    @MainActor public static var currentScreen: NSScreen? {
        NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }
}

extension NSWindow {
    /// Centres the window on the current screen at `size` (clamped to fit).
    @MainActor public func centreOnCurrentScreen(size: CGSize) {
        guard let screen = WindowPlacement.currentScreen else { return center() }
        setFrame(WindowPlacement.centred(size, in: screen.visibleFrame, minimum: minSize), display: false)
    }
}
