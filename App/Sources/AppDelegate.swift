import AppKit
import CueCore
import CueImport

/// Cue's entry point. A plain AppKit app: SwiftUI views are hosted inside
/// windows we manage ourselves, because the show needs per-screen windows
/// and native key handling.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let shared = AppDelegate()
    /// Readable by ClaudeDecks, which lets Claude list, open and save decks.
    private(set) var deckWindows: [DeckWindowController] = []
    private let imports = ImportCoordinator()
    private lazy var welcome = WelcomeWindowController(actions: WelcomeActions(
        newPresentation: { [weak self] in self?.newDocument(nil) },
        open: { [weak self] in self?.openDocument(nil) },
        openURL: { [weak self] url in self?.open(url) }
    ))
    private var settings: SettingsWindowController?

    static func main() {
        let app = NSApplication.shared
        app.delegate = shared
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        startClaude()
        if let url = LaunchOptions.deckToOpen {
            open(url, presentAt: LaunchOptions.presentImmediately ? LaunchOptions.startSlide : nil)
            if let deck = deckWindows.first {
                if LaunchOptions.rehearseImmediately { deck.present(fromSlide: LaunchOptions.startSlide, mode: .rehearse) }
                if LaunchOptions.showDisplays { deck.showDisplays(nil) }
            }
        } else if deckWindows.isEmpty {
            showWelcome(nil)
        }
        #if DEBUG
        if LaunchOptions.showSettings { showSettings(nil) }
        #endif
        NSApp.activate()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { open($0) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { ClaudeConnection.shared.stop() }

    /// Lets the user's Claude connect (MCP). Claude works on the front-most deck.
    private func startClaude() {
        ClaudeConnection.shared.frontSession = { [weak self] in
            guard let decks = self?.deckWindows else { return nil }
            // The deck Claude created or opened, while it's open; else the front-most one.
            if let target = ClaudeConnection.shared.target, let deck = decks.first(where: { $0.deck.fileURL.deckIdentity == target.deckIdentity }) {
                return deck.session
            }
            let key = decks.first { $0.window?.isKeyWindow == true } ?? decks.first { $0.window?.isMainWindow == true }
            return (key ?? decks.last)?.session
        }
        ClaudeConnection.shared.start()
    }

    /// Quitting with unsaved decks asks first, like closing their windows:
    /// one deck gets its own Save / Don't Save; several get Review Changes.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let unsaved = deckWindows.filter(\.needsSaving)
        switch unsaved.count {
        case 0:
            return .terminateNow
        case 1:
            review(unsaved)
            return .terminateLater
        default:
            switch UnsavedChangesPrompt.askBeforeQuitting(count: unsaved.count) {
            case .cancel: return .terminateCancel
            case .discardAll: return .terminateNow
            case .review:
                review(unsaved)
                return .terminateLater
            }
        }
    }

    /// Asks about each deck in turn; Cancel on any of them stops the quit.
    private func review(_ decks: [DeckWindowController]) {
        guard let deck = decks.first else { return NSApp.reply(toApplicationShouldTerminate: true) }
        deck.askToSave { [weak self] mayClose in
            guard mayClose, let self else {
                // The quit is off: decks answered "Don't Save" ask again next time.
                self?.deckWindows.forEach { $0.keepsChanges() }
                return NSApp.reply(toApplicationShouldTerminate: false)
            }
            self.review(Array(decks.dropFirst()))
        }
    }

    /// Clicking the Dock icon with nothing open brings the Welcome window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows && deckWindows.isEmpty { showWelcome(nil) }
        return true
    }

    @objc func newDocument(_ sender: Any?) {
        NewPresentation.create { [weak self] url in self?.open(url) }
    }

    @objc func showWelcome(_ sender: Any?) {
        welcome.showWindow(nil)
        welcome.window?.makeKeyAndOrderFront(nil)
    }

    @objc func showSettings(_ sender: Any?) {
        let controller = settings ?? SettingsWindowController()
        settings = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    @objc func openDocument(_ sender: Any?) {
        DeckOpener.chooseDecks { [weak self] urls in urls.forEach { self?.open($0) } }
    }

    /// Opens a deck in its own window, optionally going straight into the show.
    func open(_ url: URL, presentAt slide: Int? = nil) {
        let url = url.deckIdentity
        // PowerPoint, Keynote, OpenDocument and PDF become an HTML deck first.
        if ImportService.needsImport(url) {
            imports.open(url) { [weak self] html, report in
                self?.open(html, presentAt: slide)
                let window = self?.window(for: html)?.window
                if let report { self?.imports.showReport(report, over: window) }
            }
            return
        }
        do {
            let controller = try window(opening: url)
            controller.showWindow(nil)
            if let slide { controller.present(fromSlide: slide) }
        } catch {
            DeckOpener.reportFailure(opening: url, error: error)
        }
    }

    /// The window showing the deck at `url`, however the path is spelled.
    func window(for url: URL) -> DeckWindowController? {
        let url = url.deckIdentity
        return deckWindows.first { $0.deck.fileURL.deckIdentity == url }
    }

    /// The deck's window, made if it isn't open yet. Throws instead of
    /// showing an alert, for callers (Claude) that report errors themselves.
    func window(opening url: URL) throws -> DeckWindowController {
        if let existing = window(for: url) { return existing }
        let document = try DeckDocument(contentsOf: url.deckIdentity)
        let controller = DeckWindowController(deck: document)
        controller.onClose = { [weak self, weak controller] in
            guard let self else { return }
            deckWindows.removeAll { $0 === controller }
            if deckWindows.isEmpty { showWelcome(nil) } // The last deck closed: back to Welcome.
        }
        deckWindows.append(controller)
        welcome.close()
        NSDocumentController.shared.noteNewRecentDocumentURL(document.fileURL)
        return controller
    }
}
