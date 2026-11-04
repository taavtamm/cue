import AppKit
import CueCore
import CueUI
import SwiftUI

/// Shown when no deck is open: at launch, and after the last deck closes.
@MainActor
final class WelcomeWindowController: NSWindowController {
    private let model = WelcomeModel()
    private let actions: WelcomeActions
    static let size = CGSize(width: 920, height: 560)

    init(actions: WelcomeActions) {
        self.actions = actions
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Welcome to Cue"
        window.isMovableByWindowBackground = true
        window.minSize = CGSize(width: 760, height: 460)
        window.isReleasedWhenClosed = false // No saved frame: it always opens centred (see showWindow).
        super.init(window: window)
        window.useCueGlass(WelcomeView(model: model, actions: actions))
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [model] _ in MainActor.assumeIsolated { model.refresh() } }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("WelcomeWindowController is created in code") }

    override func showWindow(_ sender: Any?) {
        model.refresh()
        if window?.isVisible != true { window?.centreOnCurrentScreen(size: Self.size) }
        super.showWindow(sender)
        // At launch macOS can still be loading File › Open Recent, so the
        // first read may come back empty. Read it again once it has settled.
        Task { [model] in
            try? await Task.sleep(for: .milliseconds(600))
            model.refresh()
        }
        #if DEBUG
        if let window { Task { await ShowSnapshots.capture(window: window, chrome: chrome, named: "welcome.png") } }
        #endif
    }

    override func close() {
        model.thumbnails.cancel()
        super.close()
    }

    #if DEBUG
    private var chrome: AnyView {
        AnyView(ZStack {
            CueBackground()
            WelcomeView(model: model, actions: actions).background(CueGlassTint())
        }.environment(\.cueRendersStatically, true))
    }
    #endif
}
