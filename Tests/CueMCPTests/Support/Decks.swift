import CueCore
import Foundation

enum Decks {
    static let small = """
        <!doctype html><html><head><meta name="cue:canvas" content="1920x1080"></head><body>
        <section data-cue-slide id="intro" data-cue-notes="Hello"><h1 class="headline">A very long first headline</h1><p>One</p></section>
        <section data-cue-slide id="middle"><h1 class="headline">Second</h1><p class="lead">Two</p><p>Three</p></section>
        <section data-cue-slide id="end"><h1 class="headline">Our Q3 results were better than anyone expected</h1></section>
        </body></html>
        """

    /// A fresh copy on disk, so tests can check the file is never saved.
    static func document(_ html: String = small) throws -> (DeckDocument, URL) {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-mcp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "deck.html")
        try Data(html.utf8).write(to: url)
        return (try DeckDocument(contentsOf: url), url)
    }

    static let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
}
