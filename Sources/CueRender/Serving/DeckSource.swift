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
    /// Hosts the user allowed this deck to load from, e.g. "fonts.gstatic.com".
    public var allowedHosts: [String]

    public init(fileURL: URL, sourceText: String, structure: DeckStructure, allowedHosts: [String] = []) {
        self.fileURL = fileURL
        self.sourceText = sourceText
        self.structure = structure
        self.allowedHosts = allowedHosts
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
    /// Serves the document's current text, including unsaved edits.
    public init(document: DeckDocument, allowedHosts: [String] = []) {
        self.init(
            fileURL: document.fileURL,
            sourceText: document.source,
            structure: document.structure,
            allowedHosts: allowedHosts
        )
    }
}
