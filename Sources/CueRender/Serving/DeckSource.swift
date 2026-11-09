import CueCore
import Foundation

/// Everything a SlideRenderer needs to load a deck.
public struct DeckSource: Sendable {
    /// The deck's HTML file. Its folder is the only folder the page can read.
    public var fileURL: URL
    /// The file's text as last read or edited. Served instead of the bytes on disk,
    /// so unsaved edits show immediately.
    public var sourceText: String
    public var structure: DeckStructure
    /// Hosts the user allowed this deck to load from over HTTPS, e.g.
    /// "fonts.gstatic.com". Anything that isn't a bare host name is ignored.
    public var allowedHosts: [String]
    /// Camera, microphone and location for this deck. Off unless the user allowed them.
    public var permissions: DeckPermissions
    /// Plain-HTTP origins ("http://localhost") for tests against a local
    /// server. Internal, so only `@testable` code can set it; decks and
    /// stored grants never reach it.
    var insecureTestOrigins: [String] = []

    public init(
        fileURL: URL,
        sourceText: String,
        structure: DeckStructure,
        allowedHosts: [String] = [],
        permissions: DeckPermissions = .none
    ) {
        self.fileURL = fileURL
        self.sourceText = sourceText
        self.structure = structure
        self.allowedHosts = allowedHosts
        self.permissions = permissions
    }

    public var folder: DeckFolder { DeckFolder(root: fileURL.deletingLastPathComponent()) }

    /// The URL the web view loads: `cue-deck://deck/<file name>`.
    public var pageURL: URL {
        var components = URLComponents()
        components.scheme = DeckSchemeHandler.scheme
        components.host = DeckSchemeHandler.host
        components.path = "/" + fileURL.lastPathComponent
        return components.url!
    }
}

extension DeckSource {
    /// Serves the document's current text, including unsaved edits. Network
    /// and permission choices come from `grants`, never from the deck's
    /// sidecar: a deck could ship one that allows itself anything.
    public init(document: DeckDocument, grants store: DeckGrantStore = .standard) {
        let grants = store.grants(forDeck: document.fileURL)
        self.init(
            fileURL: document.fileURL,
            sourceText: document.source,
            structure: document.structure,
            allowedHosts: grants.allowedHosts,
            permissions: grants.permissions
        )
    }
}
