import Testing
@testable import CueCore

@Suite("Adapter registry")
struct AdapterRegistryTests {
    @Test(arguments: [
        ("demo-deck.html", AdapterKind.claudeDesign),
        ("misleading-hz-meta.html", .claudeDesign),
        ("cue-convention.html", .cue),
        ("reveal.html", .reveal),
        ("document-role.html", .documentRole),
        ("aria-slides.html", .documentRole),
        ("sections.html", .fallback),
        ("marp-export.html", .fallback),
        ("plain-page.html", .fallback),
    ])
    func picksTheRightAdapter(file: String, expected: AdapterKind) throws {
        #expect(try Fixtures.structure(file).adapter == expected)
    }

    @Test func cueConventionWinsOverEverything() throws {
        // A Claude Design deck that also carries Cue markers is read as Cue's.
        let html = """
        <html><head><meta name="hz:canvas-width" content="1920"><meta name="hz:canvas-height" content="1080"></head>
        <body><section class="deck-slide" data-document-role="page" data-cue-slide><h1>A</h1></section></body></html>
        """
        let input = AdapterInput(root: try HTMLParser().parse(html), source: html)
        let deck = AdapterRegistry.standard.structure(for: input)
        #expect(deck.adapter == .cue)
        #expect(deck.canvas == .hd)
    }

    @Test func emptyDocumentStillOpens() throws {
        let html = ""
        let input = AdapterInput(root: try HTMLParser().parse(html), source: html)
        let deck = AdapterRegistry.standard.structure(for: input)
        #expect(deck.slides.count == 1)
        #expect(deck.adapter == .fallback)
    }
}
