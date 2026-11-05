import AppKit

/// The menu bar. Actions travel the responder chain, so "Play Slideshow"
/// goes to whichever deck window is in front.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu(appMenu()))
        menu.addItem(submenu(fileMenu()))
        menu.addItem(submenu(editMenu()))
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
        menu.addItem(withTitle: "Settings…", action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide Cue", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: "Quit Cue", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(withTitle: "New Presentation…", action: #selector(AppDelegate.newDocument(_:)), keyEquivalent: "n")
        menu.addItem(withTitle: "Open…", action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o")
        menu.addItem(submenu(RecentDecksMenu.make()))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: "Save", action: #selector(DeckWindowController.saveDocument(_:)), keyEquivalent: "s")
        menu.addItem(withTitle: "Revert to Saved", action: #selector(DeckWindowController.revertDocumentToSaved(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(submenu(exportMenu()))
        return menu
    }

    /// File › Export: an editable PowerPoint (static), PDF or images.
    private static func exportMenu() -> NSMenu {
        let menu = NSMenu(title: "Export")
        let all = menu.addItem(withTitle: "Export…", action: #selector(DeckWindowController.exportDeck(_:)), keyEquivalent: "e")
        all.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "PowerPoint…", action: #selector(DeckWindowController.exportPowerPoint(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "PDF…", action: #selector(DeckWindowController.exportPDF(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Images…", action: #selector(DeckWindowController.exportImages(_:)), keyEquivalent: "")
        return menu
    }

    /// Undo and Redo step through deck edits (each one a source patch).
    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: #selector(DeckWindowController.undoEdit(_:)), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: #selector(DeckWindowController.redoEdit(_:)), keyEquivalent: "Z")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
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
        menu.addItem(.separator())
        menu.addItem(withTitle: "Welcome to Cue", action: #selector(AppDelegate.showWelcome(_:)),
                     keyEquivalent: "1").keyEquivalentModifierMask = [.command, .shift]
        return menu
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
