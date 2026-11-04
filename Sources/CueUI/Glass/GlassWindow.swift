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
