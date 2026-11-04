import Testing
@testable import CueCore

@Suite("Fallback adapter")
struct FallbackAdapterTests {
    @Test func topLevelSectionsOnly() throws {
        let deck = try #require(FallbackAdapter().detect(try Fixtures.input("sections.html")))
        #expect(deck.renderMode == .cueDriven)
        #expect(deck.slides.map(\.label) == ["Part one", "Part two", "Slide 3"])
        #expect(deck.slideSelector == "section:not(section section)")
        #expect(deck.slides.map(\.hasLiveContent) == [false, true, false])
    }

    @Test func marpExportWithScriptIsPassthrough() throws {
        let deck = try #require(FallbackAdapter().detect(try Fixtures.input("marp-export.html")))
        #expect(deck.slides.map(\.label) == ["Marp one", "Marp two"])
        #expect(deck.canvas == CanvasSize(width: 1280, height: 720))
        #expect(deck.renderMode == .passthrough)
        #expect(deck.slideSelector == ".marpit section")
    }

    @Test func plainPageIsOneSlide() throws {
        let deck = try #require(FallbackAdapter().detect(try Fixtures.input("plain-page.html")))
        #expect(deck.slides.count == 1)
        #expect(deck.slides[0].label == "Just a page")
        #expect(deck.slideSelector == "body")
        #expect(deck.renderMode == .passthrough)
        #expect(deck.slides[0].elementPath == [1])
    }
}
