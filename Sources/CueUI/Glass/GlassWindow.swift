import AppKit
import SwiftUI

/// Makes a titled window one sheet of Cue glass, as in the designs: the
/// system glass is the window's own background (the desktop shows through,
/// tinted by the colour pools), and the traffic lights sit inside the
/// toolbar row instead of above a separate panel.
///
/// The glass has no corner radius of its own: the titled window clips it to
/// the system's window shape, so the corners always match macOS.
extension NSWindow {
    /// Height of the toolbar row the traffic lights are centred in. Content
    /// draws its own toolbar in this band (ignoring the top safe area).
    public static let cueToolbarHeight: CGFloat = 52

    @MainActor
    public func useCueGlass(_ root: some View) {
        styleMask.insert(.fullSizeContentView)
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        titlebarSeparatorStyle = .none
        isOpaque = false
        backgroundColor = .clear
        // An empty unified toolbar gives the title bar the toolbar's height,
        // which centres the traffic lights in Cue's toolbar row.
        let toolbar = NSToolbar(identifier: "cue.glass")
        toolbar.showsBaselineSeparator = false
        self.toolbar = toolbar
        toolbarStyle = .unified

        let glass = NSGlassEffectView()
        glass.cornerRadius = 0
        glass.tintColor = NSColor(red: 12 / 255, green: 10 / 255, blue: 16 / 255, alpha: 0.55)
        glass.contentView = NSHostingView(rootView: root.background(CueGlassTint()).ignoresSafeArea())
        contentView = glass
        hidesToolbarInFullScreen()
    }

    /// In full screen macOS draws the toolbar in its own opaque strip, which
    /// for Cue's empty placeholder toolbar is a blank white band over the
    /// app's real toolbar row. Hide it while in full screen.
    @MainActor
    private func hidesToolbarInFullScreen() {
        let center = NotificationCenter.default
        center.addObserver(forName: NSWindow.willEnterFullScreenNotification, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.toolbar?.isVisible = false }
        }
        center.addObserver(forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.toolbar?.isVisible = true }
        }
    }
}

/// Makes empty parts of a glass window's toolbar row behave like a title
/// bar: drag to move the window (including dragging it to the top of the
/// screen to fill it, and the other tiling gestures) and double-click to
/// zoom, as the user set in System Settings.
public struct WindowTitleBarArea: View {
    public init() {}

    public var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .onTapGesture(count: 2) { NSApp.keyWindow?.performZoom(nil) }
            .accessibilityHidden(true)
    }
}

/// The colour pools from the designs, laid over the window glass as a
/// translucent tint: purple top-left, blue top-right, wine along the bottom.
public struct CueGlassTint: View {
    public init() {}

    public var body: some View {
        CueBackground(groundOpacity: 0.35, poolOpacity: 0.6)
            .allowsHitTesting(false)
    }
}
