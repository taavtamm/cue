import CueCore
import Foundation
import Testing
@testable import CueRender

/// A deck shipped with its own `deck.cue.json` can't grant itself anything:
/// grants come only from Cue's store, which the deck can't write.
@Suite("Sidecar can't grant", .serialized)
@MainActor
struct SidecarGrantTests {
    @Test func aSidecarGrantingAHostGetsNoNetwork() async throws {
        let server = try LocalServer()
        defer { server.stop() }
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-sidecar-grant-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let deck = folder.appending(path: "deck.html")
        try Data("""
            <!doctype html><html><body><section data-cue-slide id="a"><h1>Hi</h1></section>
            <script>
              const done = (what) => document.body.setAttribute('data-result', what);
              fetch('\(server.origin)/sidecar-fetch').then(() => done('loaded'), () => done('blocked'));
              const image = new Image();
              image.src = 'https://127.0.0.1:\(server.port)/sidecar-img.png';
            </script></body></html>
            """.utf8).write(to: deck)
        // Everything an older Cue would have honoured, written by the deck's author.
        try Data(#"""
            {"version": 1, "allowedHosts": ["http://127.0.0.1", "127.0.0.1", "localhost"],
             "permissions": {"camera": true, "microphone": true, "location": true}}
            """#.utf8).write(to: CueSidecar.url(forDeck: deck))

        let store = DeckGrantStore(fileURL: folder.appending(path: "empty-store/deck-grants.json"))
        let source = DeckSource(document: try DeckDocument(contentsOf: deck), grants: store)
        #expect(source.allowedHosts.isEmpty)
        #expect(source.permissions == .none)

        let harness = RendererHarness()
        defer { harness.close() }
        try await harness.load(source)
        try await harness.waitUntilAsync("fetch settled") {
            let result: String? = try? await harness.evaluate("return document.body.getAttribute('data-result')")
            return result != nil
        }
        let result: String = try await harness.evaluate("return document.body.getAttribute('data-result')")
        try await Task.sleep(for: .milliseconds(500))
        #expect(result == "blocked")
        #expect(server.connections == 0, "\(server.requests.map(\.line))")
    }

    @Test func grantsComeFromTheStore() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-store-grant-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let deck = folder.appending(path: "deck.html")
        try Data("<!doctype html><section data-cue-slide><h1>Hi</h1></section>".utf8).write(to: deck)
        let store = DeckGrantStore(fileURL: folder.appending(path: "store.json"))
        try store.update(forDeck: deck) {
            $0.allowedHosts = ["fonts.gstatic.com"]
            $0.permissions.location = true
        }
        let source = DeckSource(document: try DeckDocument(contentsOf: deck), grants: store)
        #expect(source.allowedHosts == ["fonts.gstatic.com"])
        #expect(source.permissions == DeckPermissions(location: true))
    }
}
