import Foundation
import Testing
@testable import CueCore

@Suite("Where a deck came from")
struct DeckOriginTests {
    private func document(_ html: String) throws -> DeckDocument {
        let url = FileManager.default.temporaryDirectory.appending(path: "cue-origin-\(UUID().uuidString).html")
        try Data(html.utf8).write(to: url)
        return try DeckDocument(contentsOf: url)
    }

    @Test func importedDecksNameTheirOriginal() throws {
        let deck = try document("""
            <!doctype html><html><head><meta name="cue:imported-from" content="Talk.pptx"></head>
            <body><section data-cue-slide>One</section></body></html>
            """)
        #expect(deck.importedFrom == "Talk.pptx")
    }

    @Test func ordinaryDecksHaveNoOriginal() throws {
        let deck = try document("<!doctype html><html><head></head><body><section>One</section></body></html>")
        #expect(deck.importedFrom == nil)
    }
}
