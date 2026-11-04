import Foundation
import Testing
@testable import CueCore

@Suite("Element edits")
struct ElementEditTests {
    @Test func textIsEscapedAndOnlyTheContentChanges() throws {
        var document = try Editing.document("cue-convention.html")
        let before = document.source
        let h1 = try Editing.path(in: document, tag: "h1")
        let result = try document.apply(.setText(h1, "Tom & Jerry <3"))
        #expect(document.source.contains("<h1>Tom &amp; Jerry &lt;3</h1>"))
        Editing.expectWithin(try Editing.document("cue-convention.html").sourceMap.element(at: h1)?.innerRange,
                             before: before, after: document.source)
        #expect(document.structure.slides[0].label == "Tom & Jerry <3")
        #expect(result.live == .inPlace([.setInnerHTML(cueID: document.sourceMap.element(at: h1)!.cueID,
                                                       html: "Tom &amp; Jerry &lt;3")], remap: false))
    }

    @Test func attributesKeepTheirQuoteStyle() throws {
        var document = try Editing.document(html: "<html><body><p title='a' class=x hidden>Hi</p></body></html>")
        let p = try Editing.path(in: document, tag: "p")
        try document.apply(.setAttribute(p, name: "title", value: "it's \"quoted\""))
        #expect(document.source.contains("title='it&#39;s \"quoted\"'"))
        try document.apply(.setAttribute(p, name: "class", value: "y z"))
        #expect(document.source.contains("class=\"y z\""))
        try document.apply(.setAttribute(p, name: "data-new", value: "1"))
        #expect(document.source.contains("hidden data-new=\"1\">Hi"))
        try document.apply(.setAttribute(p, name: "hidden", value: nil))
        #expect(document.source == "<html><body><p title='it&#39;s \"quoted\"' class=\"y z\" data-new=\"1\">Hi</p></body></html>")
    }

    @Test func styleEditsKeepOtherDeclarations() throws {
        var document = try Editing.document(html: "<html><body><p style=\"color: red;margin:0\">Hi</p><b>x</b></body></html>")
        let p = try Editing.path(in: document, tag: "p")
        let result = try document.apply(.setStyle(p, property: "color", value: "#141414"))
        #expect(document.source.contains("style=\"color: #141414;margin:0\""))
        if case .inPlace(let changes, _) = result.live {
            #expect(changes == [.setAttribute(cueID: document.sourceMap.element(at: p)!.cueID, name: "style",
                                              value: "color: #141414;margin:0")])
        } else {
            Issue.record("a style edit should apply in place")
        }
        let b = try Editing.path(in: document, tag: "b")
        try document.apply(.setStyle(b, property: "font-weight", value: "400"))
        #expect(document.source.contains("<b style=\"font-weight: 400\">x</b>"))
        try document.apply(.setStyle(p, property: "font-family", value: "\"Inter\", sans-serif"))
        #expect(document.source.contains("margin:0; font-family: &quot;Inter&quot;, sans-serif\""))
    }

    @Test func refusesEditsThatWouldCorruptTheFile() throws {
        var document = try Editing.document(
            html: "<html><head><style>p{}</style><script>let a</script></head><body><p>a<b>b</b></p><img src=x></body></html>"
        )
        #expect(throws: EditError.rawTextElement("style")) {
            try document.apply(.setText(try Editing.path(in: document, tag: "style"), "x"))
        }
        #expect(throws: EditError.rawTextElement("script")) {
            try document.apply(.setText(try Editing.path(in: document, tag: "script"), "x"))
        }
        #expect(throws: EditError.notALeaf) { try document.apply(.setText(try Editing.path(in: document, tag: "p"), "x")) }
        #expect(throws: EditError.voidElement("img")) {
            try document.apply(.setText(try Editing.path(in: document, tag: "img"), "x"))
        }
        let p = try Editing.path(in: document, tag: "p")
        #expect(throws: EditError.invalidAttributeName("data-cue-id")) {
            try document.apply(.setAttribute(p, name: "data-cue-id", value: "3"))
        }
        #expect(throws: (any Error).self) { try document.apply(.setStyle(p, property: "color", value: "red; x: y")) }
        #expect(!document.isModified)
    }

    @Test func unchangedEditsChangeNothing() throws {
        var document = try Editing.document("cue-convention.html")
        let body = try Editing.path(in: document, tag: "body")
        #expect(try document.apply(.setAttribute(body, name: "data-missing", value: nil)) == .none)
        #expect(!document.history.canUndo)
    }
}
