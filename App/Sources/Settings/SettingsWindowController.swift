import AppKit
import CueCore
import CueUI
import SwiftUI

/// Cue › Settings… (⌘,). One shared window.
@MainActor
final class SettingsWindowController: NSWindowController {
    static let size = CGSize(width: 860, height: 600)

    init(section: SettingsSection = .general) {
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Settings"
        window.minSize = CGSize(width: 720, height: 460)
        window.isReleasedWhenClosed = false // No saved frame: it always opens centred (see showWindow).
        super.init(window: window)
        window.useCueGlass(SettingsView(settings: .shared, section: section))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("SettingsWindowController is created in code") }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible != true { window?.centreOnCurrentScreen(size: Self.size) }
        super.showWindow(sender)
        #if DEBUG
        guard let window else { return }
        for section in SettingsSection.allCases where ShowSnapshots.request != nil {
            let chrome = AnyView(ZStack {
                CueBackground()
                SettingsView(settings: .shared, section: section).background(CueGlassTint())
            }.environment(\.cueRendersStatically, true))
            let name = "settings-\(section.rawValue).png"
            Task { await ShowSnapshots.capture(window: window, chrome: chrome, named: name) }
        }
        #endif
    }
}
