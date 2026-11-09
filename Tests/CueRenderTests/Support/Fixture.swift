import CueCore
import Foundation
@testable import CueRender

/// Test decks, copied to a fresh temp folder so the originals stay untouched.
enum Fixture {
    static let repoRoot = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    static var demoDeckURL: URL { repoRoot.appending(path: "fixtures/demo-deck.html") }

    /// A temp folder containing a copy of the demo deck as `deck.html`.
    static func demoDeckCopy() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-render-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appending(path: "deck.html")
        try FileManager.default.copyItem(at: demoDeckURL, to: copy)
        return copy
    }

    static func demoDeckSource() throws -> DeckSource {
        DeckSource(document: try DeckDocument(contentsOf: try demoDeckCopy()))
    }

    /// A small deck written to a temp folder, analysed by the real adapters.
    static func deck(named name: String = "deck.html", html: String) throws -> DeckSource {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-render-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: name)
        try Data(html.utf8).write(to: file)
        return DeckSource(document: try DeckDocument(contentsOf: file))
    }
}
