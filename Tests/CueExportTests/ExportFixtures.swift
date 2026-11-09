import CueCore
import Foundation

/// Fixture decks copied to a temp folder (the originals are never touched).
enum ExportFixtures {
    static let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()

    static func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func demoDeck() throws -> DeckDocument {
        let copy = try folder().appending(path: "demo-deck.html")
        try FileManager.default.copyItem(at: repoRoot.appending(path: "fixtures/demo-deck.html"), to: copy)
        return try DeckDocument(contentsOf: copy)
    }

    static func deck(_ html: String, name: String = "deck.html") throws -> DeckDocument {
        let url = try folder().appending(path: name)
        try Data(html.utf8).write(to: url)
        return try DeckDocument(contentsOf: url)
    }
}

/// Checks every XML part of a package is well-formed.
final class XMLCheck: NSObject, XMLParserDelegate {
    static func isWellFormed(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        return parser.parse()
    }
}
