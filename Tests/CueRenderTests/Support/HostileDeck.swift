import CueCore
import Foundation
@testable import CueRender

/// Lays out the hostile fixture the way its header describes:
///   <tmp>/secret.txt, <tmp>/secret.png        outside the deck folder
///   <tmp>/deck/hostile.html, hostile-attempts.js, inside.txt
///   <tmp>/deck/link-to-secret.txt → ../secret.txt
/// and allows one host, `allowedOrigin`, so the deck can try to pass for it.
enum HostileDeck {
    /// Allowed for the hostile deck. Never resolves; the deck only borrows its name.
    static let allowedOrigin = "http://cue-allowed.test"

    struct Setup {
        var source: DeckSource
        var token: String
    }

    static func make(server: LocalServer, page: String = "hostile.html") throws -> Setup {
        let root = FileManager.default.temporaryDirectory.appending(path: "cue-hostile-\(UUID().uuidString)")
        let deck = root.appending(path: "deck")
        try FileManager.default.createDirectory(at: deck, withIntermediateDirectories: true)
        let token = "SECRET-\(UUID().uuidString)"
        let secret = root.appending(path: "secret.txt").resolvingSymlinksInPath()
        try Data(token.utf8).write(to: secret)
        try onePixelPNG.write(to: root.appending(path: "secret.png"))
        try Data("INSIDE".utf8).write(to: deck.appending(path: "inside.txt"))
        let link = deck.appending(path: "link-to-secret.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: secret)

        for name in [page, "hostile-attempts.js"] {
            let original = Fixture.repoRoot.appending(path: "fixtures/\(name)")
            guard FileManager.default.fileExists(atPath: original.path) else { continue }
            let text = try String(contentsOf: original, encoding: .utf8)
                .replacingOccurrences(of: "__SERVER__", with: server.origin)
                .replacingOccurrences(of: "__SECRET__", with: secret.path)
                .replacingOccurrences(of: "__TOKEN__", with: token)
                .replacingOccurrences(of: "__ALLOWED__", with: allowedOrigin)
            try Data(text.utf8).write(to: deck.appending(path: name))
        }
        let document = try DeckDocument(contentsOf: deck.appending(path: page))
        let noGrants = DeckGrantStore(fileURL: root.appending(path: "no-grants.json"))
        var source = DeckSource(document: document, grants: noGrants)
        source.insecureTestOrigins = [allowedOrigin] // Plain HTTP, like the local server.
        return Setup(source: source, token: token)
    }

    static let onePixelPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
}
