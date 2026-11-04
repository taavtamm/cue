import Foundation
import Testing
@testable import CueCore

@Suite("Slide structure edits")
struct SlideEditTests {
    private func labels(_ document: DeckDocument) -> [String] { document.structure.slides.map(\.label) }

    @Test func addDeleteMoveOnACueDeck() throws {
        var document = try Editing.document("cue-convention.html")
        let original = labels(document)
        let added = try document.apply(.addSlide(after: 0, html: "<section data-cue-slide><h1>Inserted</h1></section>"))
        #expect(added.live == .reload)
        #expect(labels(document) == [original[0], "Inserted", original[1], original[2]])
        try document.apply(.moveSlide(from: 1, to: 3))
        #expect(labels(document) == [original[0], original[1], original[2], "Inserted"])
        try document.apply(.moveSlide(from: 3, to: 0))
        #expect(labels(document) == ["Inserted", original[0], original[1], original[2]])
        try document.apply(.deleteSlide(0))
        #expect(labels(document) == original)
        #expect(document.source == (try String(contentsOf: document.fileURL, encoding: .utf8)))
    }

    @Test func blankSlidesCopyTheDeckWrappers() throws {
        var document = try Editing.document("demo-deck.html")
        try document.apply(.addSlide(after: 2, html: nil))
        let slides = document.structure.slides
        #expect(slides.count == 13)
        #expect(slides[3].label == "New slide")
        #expect(slides[3].notes.isEmpty)
        let element = try #require(document.sourceMap.element(at: slides[3].elementPath))
        let markup = SourceText(document.source).slice(element.range!)
        #expect(markup.contains("class=\"deck-fit\"") && markup.contains("class=\"deck-scaler\""))
        #expect(!markup.contains("data-frame-id"))
        #expect(try motionSlideCount(document) == 13)
    }

    @Test func claudeDesignMovesKeepDeckMotionInStep() throws {
        var document = try Editing.document("demo-deck.html")
        let before = try motionEmbedIDs(document)
        let labelsBefore = labels(document)
        try document.apply(.moveSlide(from: 1, to: 4))
        var expected = labelsBefore
        expected.insert(expected.remove(at: 1), at: 4)
        #expect(labels(document) == expected)
        var expectedEmbeds = before
        expectedEmbeds.insert(expectedEmbeds.remove(at: 1), at: 4)
        #expect(try motionEmbedIDs(document) == expectedEmbeds)
        try document.apply(.deleteSlide(11))
        #expect(document.structure.slides.count == 11)
        #expect(try motionSlideCount(document) == 11)
        try document.undo()
        try document.undo()
        #expect(!document.isModified)
    }

    @Test func theLastSlideCannotBeDeleted() throws {
        var document = try Editing.document("latin1.html")
        #expect(throws: EditError.lastSlide) { try document.apply(.deleteSlide(0)) }
    }

    private func motion(_ document: DeckDocument) throws -> [[String: Any]] {
        let script = try #require(document.sourceMap.elements.first { $0.attributes["id"] == "deck-motion" })
        let json = SourceText(document.source).slice(script.innerRange!)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        return object?["slides"] as? [[String: Any]] ?? []
    }

    private func motionSlideCount(_ document: DeckDocument) throws -> Int { try motion(document).count }

    private func motionEmbedIDs(_ document: DeckDocument) throws -> [String] {
        try motion(document).map { slide in
            ((slide["embeds"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String }.joined(separator: ",")
        }
    }
}
