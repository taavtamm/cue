import Foundation
import Testing
@testable import CueCore

/// Network and device grants live in Cue's own store, keyed by the deck's
/// resolved path, and never in the sidecar a deck can ship with.
@Suite("Deck grant store")
struct DeckGrantStoreTests {
    private func tempFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-grants-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test func choicesRoundTripPerDeck() throws {
        let folder = try tempFolder()
        let store = DeckGrantStore(fileURL: folder.appending(path: "support/Cue/deck-grants.json"))
        let deck = folder.appending(path: "a.html")
        let other = folder.appending(path: "b.html")
        #expect(store.grants(forDeck: deck) == .none)

        try store.update(forDeck: deck) { $0.allowedHosts = ["fonts.gstatic.com"] }
        try store.update(forDeck: deck) { $0.permissions.camera = true }
        try store.update(forDeck: other) { $0.deniedHosts = ["evil.example"] }

        #expect(store.grants(forDeck: deck).allowedHosts == ["fonts.gstatic.com"])
        #expect(store.grants(forDeck: deck).permissions == DeckPermissions(camera: true))
        #expect(store.grants(forDeck: other).deniedHosts == ["evil.example"])
        #expect(store.all().count == 2)

        try store.update(forDeck: other) { $0.deniedHosts = [] }
        #expect(store.all().count == 1, "A deck with no choices left is dropped")
    }

    @Test func aLinkToTheDeckSharesItsChoices() throws {
        let folder = try tempFolder()
        let store = DeckGrantStore(fileURL: folder.appending(path: "grants.json"))
        let deck = folder.appending(path: "deck.html")
        try Data("<html></html>".utf8).write(to: deck)
        let link = folder.appending(path: "link.html")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: deck)

        try store.update(forDeck: link) { $0.allowedHosts = ["fonts.gstatic.com"] }
        #expect(store.grants(forDeck: deck).allowedHosts == ["fonts.gstatic.com"])
    }

    @Test func anUnreadableStoreGrantsNothingAndIsNeverReplaced() throws {
        let folder = try tempFolder()
        let url = folder.appending(path: "grants.json")
        let damaged = Data(#"{"/x/deck.html": {"allowedHosts": "not a list"}}"#.utf8)
        try damaged.write(to: url)
        let store = DeckGrantStore(fileURL: url)
        #expect(store.grants(forDeck: URL(filePath: "/x/deck.html")) == .none)
        #expect(throws: (any Error).self) {
            try store.update(forDeck: URL(filePath: "/x/deck.html")) { $0.allowedHosts = ["a.example"] }
        }
        #expect(try Data(contentsOf: url) == damaged)
    }

    @Test func grantKeysInASidecarAreIgnored() throws {
        let json = Data(#"""
            {"version": 1, "allowedHosts": ["evil.example"], "deniedHosts": [],
             "permissions": {"camera": true, "microphone": true, "location": true}, "targetDuration": 600}
            """#.utf8)
        let sidecar = try JSONDecoder().decode(CueSidecar.self, from: json)
        #expect(sidecar.targetDuration == 600)
        let encoded = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(sidecar)) as? [String: Any]
        )
        #expect(encoded["allowedHosts"] == nil && encoded["permissions"] == nil)
    }
}
