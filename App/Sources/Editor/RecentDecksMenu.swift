import AppKit

/// File › Open Recent, built from the decks Cue opened before. Cue doesn't
/// use NSDocument, so the menu is filled in here each time it opens.
@MainActor
final class RecentDecksMenu: NSObject, NSMenuDelegate {
    private static let shared = RecentDecksMenu()

    static func make() -> NSMenu {
        let menu = NSMenu(title: "Open Recent")
        menu.delegate = shared
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let urls = NSDocumentController.shared.recentDocumentURLs
        for url in urls {
            let item = menu.addItem(withTitle: url.lastPathComponent, action: #selector(open(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            item.toolTip = url.path
        }
        if !urls.isEmpty { menu.addItem(.separator()) }
        let clear = menu.addItem(withTitle: "Clear Menu", action: #selector(clear(_:)), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !urls.isEmpty
    }

    @objc private func open(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSApp.delegate?.application?(NSApp, open: [url]) // The same path as opening from Finder.
    }

    @objc private func clear(_ sender: Any?) {
        NSDocumentController.shared.clearRecentDocuments(nil)
    }
}
