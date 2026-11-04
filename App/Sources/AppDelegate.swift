import AppKit
import CueCore

/// Cue's entry point. A plain AppKit app: SwiftUI views are hosted inside
/// windows we manage ourselves, because the show needs per-screen windows
/// and native key handling.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let shared = AppDelegate()
    private var deckWindows: [DeckWindowController] = []

    static func main() {
        let app = NSApplication.shared
        app.delegate = shared
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        if let url = LaunchOptions.deckToOpen {
            open(url, presentAt: LaunchOptions.presentImmediately ? LaunchOptions.startSlide : nil)
        } else if deckWindows.isEmpty {
            openDocument(nil)
        }
        NSApp.activate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { open($0) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc func openDocument(_ sender: Any?) {
        DeckOpener.chooseDecks { [weak self] urls in urls.forEach { self?.open($0) } }
    }

    /// Opens a deck in its own window, optionally going straight into the show.
    func open(_ url: URL, presentAt slide: Int? = nil) {
        if let existing = deckWindows.first(where: { $0.deck.fileURL == url }) {
            existing.showWindow(nil)
            return
        }
        do {
            let document = try DeckDocument(contentsOf: url)
            let controller = DeckWindowController(deck: document)
            controller.onClose = { [weak self, weak controller] in
                self?.deckWindows.removeAll { $0 === controller }
            }
            deckWindows.append(controller)
            controller.showWindow(nil)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            if let slide { controller.present(fromSlide: slide) }
        } catch {
            DeckOpener.reportFailure(opening: url, error: error)
        }
    }
}
