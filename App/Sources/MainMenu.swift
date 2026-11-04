import AppKit

/// The menu bar. Actions travel the responder chain, so "Play Slideshow"
/// goes to whichever deck window is in front.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu(appMenu()))
        menu.addItem(submenu(fileMenu()))
        menu.addItem(submenu(playMenu()))
        let window = windowMenu()
        menu.addItem(submenu(window))
        NSApp.windowsMenu = window
        return menu
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "Cue")
        let about = #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        menu.addItem(withTitle: "About Cue", action: about, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide Cue", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: "Quit Cue", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(withTitle: "Open…", action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }

    private static func playMenu() -> NSMenu {
        let menu = NSMenu(title: "Play")
        let playAction = #selector(DeckWindowController.playSlideshow(_:))
        let play = menu.addItem(withTitle: "Play Slideshow", action: playAction, keyEquivalent: "p")
        play.keyEquivalentModifierMask = [.command, .option]
        let fromStart = #selector(DeckWindowController.playFromStart(_:))
        menu.addItem(withTitle: "Play from Start", action: fromStart, keyEquivalent: "")
        menu.addItem(withTitle: "Rehearse on This Mac", action: #selector(DeckWindowController.rehearse(_:)),
                     keyEquivalent: "r").keyEquivalentModifierMask = [.command, .option]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Displays…", action: #selector(DeckWindowController.showDisplays(_:)),
                     keyEquivalent: "d").keyEquivalentModifierMask = [.command, .option]
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        return menu
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
