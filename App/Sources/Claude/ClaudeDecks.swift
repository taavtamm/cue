import AppKit
import CueCore
import CueImport
import CueMCP

/// Lets Claude make, open, switch between and save presentations (the
/// create_deck, open_deck, list_decks and save_deck tools). Windows come
/// forward without activating Cue, so the user's terminal keeps the keyboard.
@MainActor
enum ClaudeDecks {
    private static var app: AppDelegate? { NSApp.delegate as? AppDelegate }

    static func summaries() -> [DeckSummary] {
        let open = (app?.deckWindows ?? []).map { summary(of: $0) }
        let openPaths = Set(open.map(\.path))
        let recent = NSDocumentController.shared.recentDocumentURLs
            .filter { !openPaths.contains($0.path) && FileManager.default.fileExists(atPath: $0.path) }
            .prefix(10)
            .map { DeckSummary(path: $0.path, title: $0.deletingPathExtension().lastPathComponent, slides: nil,
                               isOpen: false, isTarget: false, hasUnsavedChanges: false) }
        return open + recent
    }

    static func create(at url: URL, title: String, html: String?) throws -> DeckSummary {
        let settings = CueSettings.shared
        let text = html ?? BlankDeckTemplate.html(title: title, fontFamily: settings.defaultFontFamily,
                                                  subtitleSize: settings.defaultFontSize)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // `withoutOverwriting`: the name was checked free, but never clobber a file that appeared since.
        try Data(text.utf8).write(to: url, options: .withoutOverwriting)
        return try show(url)
    }

    static func open(_ url: URL) async throws -> DeckSummary {
        let html = ImportService.needsImport(url) ? try await ImportService().prepare(url).htmlURL : url
        return try show(html)
    }

    static func save() throws -> DeckSummary {
        guard let controller = targetController() else { throw CueMCPError.noDeck }
        try controller.session.save()
        controller.window?.isDocumentEdited = false
        return summary(of: controller)
    }

    /// Opens (or finds) the deck's window, brings it forward and makes it Claude's target.
    private static func show(_ url: URL) throws -> DeckSummary {
        app?.open(url)
        guard let controller = app?.deckWindows.first(where: { $0.deck.fileURL == url }) else {
            throw CueMCPError.invalid("Cue couldn't open \(url.lastPathComponent).")
        }
        controller.window?.orderFrontRegardless()
        ClaudeConnection.shared.target = url
        return summary(of: controller)
    }

    private static func targetController() -> DeckWindowController? {
        guard let session = ClaudeConnection.shared.frontSession() else { return nil }
        return app?.deckWindows.first { $0.session === session }
    }

    private static func summary(of controller: DeckWindowController) -> DeckSummary {
        let url = controller.deck.fileURL
        return DeckSummary(path: url.path, title: controller.session.title, slides: controller.deck.structure.slides.count,
                           isOpen: true, isTarget: targetController() === controller, hasUnsavedChanges: controller.session.isDirty)
    }
}
