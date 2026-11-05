import CueCore
import Foundation
import MCP
import Testing
@testable import CueMCP

/// create_deck, list_decks, open_deck and save_deck.
@Suite("Deck tools")
struct DeckToolTests {
    @Test func createDeckWritesAFreshDeckAndMakesItTheTarget() async throws {
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        let mcp = try await MCPHarness.connect(host)
        let created = try await mcp.call("create_deck", ["title": "Pitch"])
        #expect(!created.isError, "\(created.text)")
        let path = await host.newDeckFolder().appending(path: "Pitch.html").path
        #expect(FileManager.default.fileExists(atPath: path))
        #expect(created.text.contains("\"target\" : true"))
        let outline = try await mcp.call("get_outline")
        #expect(outline.text.contains("Pitch.html"), "the other tools now work on the new deck")

        let again = try await mcp.call("create_deck", ["title": "Pitch"])
        #expect(again.text.contains("Pitch 2.html"), "never over an existing file")
    }

    @Test func createDeckTakesAWholeHTMLDeck() async throws {
        let (document, _) = try Decks.document()
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let html = """
            <!doctype html><html><head><meta name="cue:canvas" content="1920x1080"></head><body>
            <section data-cue-slide id="a"><h1>One</h1></section><section data-cue-slide id="b"><h1>Two</h1></section>
            </body></html>
            """
        let created = try await mcp.call("create_deck", ["title": "Two slides", "html": .string(html)])
        #expect(created.text.contains("\"slides\" : 2"), "\(created.text)")
    }

    @Test func newDecksStayInsideTheHomeFolder() async throws {
        let (document, _) = try Decks.document()
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let refused = try await mcp.call("create_deck", ["title": "Escape", "folder": "/tmp"])
        #expect(refused.isError && refused.text.contains("home folder"))
    }

    @Test func saveAndListDecks() async throws {
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        let mcp = try await MCPHarness.connect(host)
        _ = try await mcp.call("create_deck", ["title": "Saved one"])
        let saved = try await mcp.call("save_deck")
        #expect(!saved.isError)
        #expect(await host.saved == 1)
        let list = try await mcp.call("list_decks")
        #expect(list.text.contains("Saved one.html"))
    }

    @Test func fileNamesAreSafe() {
        #expect(NewDeckLocation.fileName(for: "Q3 / Q4: plans") == "Q3 - Q4- plans")
        #expect(NewDeckLocation.fileName(for: "  ..hidden") == "hidden")
        #expect(NewDeckLocation.fileName(for: "   ") == "Untitled Presentation")
    }
}
