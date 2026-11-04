import AppKit
import CueUI
import SwiftUI

/// The Displays window: a glass panel with the screen arrangement and roles.
@MainActor
final class DisplaysWindowController: NSWindowController {
    /// The SwiftUI root, for Debug snapshots.
    private(set) var chrome: AnyView?

    init(coordinator: DisplayCoordinator, onRehearse: @escaping () -> Void, onStart: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1200, height: 790),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Displays"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.minSize = CGSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let view = DisplaysView(
            coordinator: coordinator,
            onRehearse: { [weak self] in self?.close(); onRehearse() },
            onStart: { [weak self] in self?.close(); onStart() }
        )
        window.contentView = NSHostingView(rootView: view)
        chrome = AnyView(ZStack { CueBackground(); view.padding(40) })
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("DisplaysWindowController is created in code") }
}
