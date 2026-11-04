import CoreGraphics
import Foundation
import Testing
@testable import CueCore

@Suite("Hand editing operations")
struct HandEditingTests {
    static let deck = """
        <!doctype html><html><head></head><body>
        <section data-cue-slide id="a">
          <h1 id="title" class="headline">Hello</h1>
          <p style="color: red;">Body</p>
        </section>
        <section data-cue-slide id="b"><h1>Two</h1></section>
        </body></html>
        """

    @Test func setStylesIsOnePatchInsideTheStartTagAndUndoesExactly() throws {
        var document = try Editing.document(html: Self.deck)
        let original = document.source
        let path = try Editing.path(in: document, tag: "p")
        let result = try document.apply(.setStyles(path, [StyleChange("translate", "10px 20px"), StyleChange("width", "300px")]))
        #expect(result.edit.patches.count == 1)
        #expect(document.source.contains(#"<p style="color: red; translate: 10px 20px; width: 300px;">"#))
        #expect(result.live != .reload)
        try document.undo()
        #expect(document.source == original)
    }

    @Test func setStylesAddsAStyleAttributeWhenThereIsNone() throws {
        var document = try Editing.document(html: Self.deck)
        let path = try Editing.path(in: document, tag: "h1")
        try document.apply(.setStyles(path, [StyleChange("translate", "4px 0px")]))
        #expect(document.source.contains(#"<h1 id="title" class="headline" style="translate: 4px 0px">"#))
    }

    @Test func nudgesOfTheSameElementUndoAsOneStep() throws {
        var document = try Editing.document(html: Self.deck)
        let original = document.source
        let path = try Editing.path(in: document, tag: "p")
        let now = Date()
        for step in 1...5 {
            try document.apply(.setStyles(path, [StyleChange("translate", "\(step)px 0px")]), at: now.addingTimeInterval(Double(step) * 0.1))
        }
        #expect(document.history.undoCount == 1)
        try document.undo()
        #expect(document.source == original)
    }

    @Test func insertedElementsGoInsideTheSlideAndComeOutAgain() throws {
        var document = try Editing.document(html: Self.deck)
        let original = document.source
        let html = ElementTemplate.textBox(text: "New", fontSize: 40, fontFamily: nil)
            .html(id: "cue-new", frame: CGRect(x: 10, y: 20, width: 300, height: 60))
        let result = try document.apply(.insertElement(slide: 0, html: html))
        #expect(document.structure.slides.count == 2)
        let inserted = try #require(document.sourceMap.elements.first { $0.attributes["id"] == "cue-new" })
        #expect(inserted.path.dropLast() == document.structure.slides[0].elementPath[...])
        guard case .inPlace(let changes, remap: true) = result.live, case .insertHTML = changes.first else {
            Issue.record("expected a live insert, got \(result.live)")
            return
        }
        try document.apply(.deleteElement(inserted.path))
        #expect(document.source == original)
    }

    @Test func deletingASlideAsAnElementIsRefused() throws {
        var document = try Editing.document(html: Self.deck)
        #expect(throws: EditError.self) { try document.apply(.deleteElement(document.structure.slides[0].elementPath)) }
    }

    @Test func formattedTextIsSanitisedBeforeItIsWritten() throws {
        var document = try Editing.document(html: Self.deck)
        let path = try Editing.path(in: document, tag: "h1")
        try document.apply(.setInnerHTML(path, #"Hi <b onclick="x()">there</b><script>alert(1)</script> <a href="javascript:x">no</a>"#))
        #expect(document.source.contains("<h1 id=\"title\" class=\"headline\">Hi <b>there</b> <a>no</a></h1>"))
    }

    @Test func insertingIntoTheFernwickDeckLandsInsideTheSlideCanvas() throws {
        var document = try Editing.document("demo-deck.html")
        let html = ElementTemplate.shape(.ellipse).html(id: "cue-dot", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        try document.apply(.insertElement(slide: 2, html: html))
        let dot = try #require(document.sourceMap.elements.first { $0.attributes["id"] == "cue-dot" })
        let parent = try #require(document.sourceMap.element(at: Array(dot.path.dropLast())))
        #expect(parent.attributes["class"] == "slide", "inside the 1920 × 1080 canvas, not a wrapper")
        #expect(document.structure.slides.count == 12)
    }

    @Test func formattedTextIsRefusedInsideDrawings() throws {
        var document = try Editing.document(html: """
            <!doctype html><html><body><section data-cue-slide><svg><text>t</text></svg></section></body></html>
            """)
        let path = try Editing.path(in: document, tag: "text")
        #expect(throws: EditError.self) { try document.apply(.setInnerHTML(path, "<b>x</b>")) }
    }
}
