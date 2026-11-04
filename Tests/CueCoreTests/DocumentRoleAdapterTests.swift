import Testing
@testable import CueCore

@Suite("Document role adapter")
struct DocumentRoleAdapterTests {
    @Test func detectsDataDocumentRolePages() throws {
        let deck = try #require(DocumentRoleAdapter().detect(try Fixtures.input("document-role.html")))
        #expect(deck.adapter == .documentRole)
        #expect(deck.slideSelector == #"[data-document-role="page"]"#)
        // "Slide 1 of 2" is position noise, so the heading becomes the label.
        #expect(deck.slides.map(\.label) == ["First page", "Second page"])
        #expect(deck.slides[0].notes == "Open strong.")
        #expect(deck.slides.map(\.hasLiveContent) == [false, true])
    }

    @Test func detectsAriaRoleDescriptionSlides() throws {
        let deck = try #require(DocumentRoleAdapter().detect(try Fixtures.input("aria-slides.html")))
        #expect(deck.slideSelector == #"[aria-roledescription="slide"]"#)
        #expect(deck.slides.map(\.label) == ["Opening", "Closing"])
    }

    @Test func ignoresOtherFormats() throws {
        for name in ["reveal.html", "sections.html", "plain-page.html"] {
            #expect(DocumentRoleAdapter().detect(try Fixtures.input(name)) == nil, "\(name)")
        }
    }
}
