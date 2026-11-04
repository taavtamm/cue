import Testing
@testable import CueCore

@Suite("reveal.js adapter")
struct RevealAdapterTests {
    @Test func flattensVerticalStacks() throws {
        let deck = try #require(RevealAdapter().detect(try Fixtures.input("reveal.html")))
        #expect(deck.adapter == .reveal)
        #expect(deck.renderMode == .passthrough)
        #expect(deck.slides.map(\.label) == ["Reveal title", "Vertical one", "Vertical two", "Fragments"])
        #expect(deck.slideSelector.contains(".reveal .slides > section > section"))
    }

    @Test func readsNotesAndCanvas() throws {
        let deck = try #require(RevealAdapter().detect(try Fixtures.input("reveal.html")))
        #expect(deck.slides[0].notes == "Welcome everyone.")
        #expect(deck.slides[2].notes == "Down we go.")
        #expect(deck.canvas == CanvasSize(width: 1280, height: 720))
    }

    @Test func countsFragmentsAsBuilds() throws {
        let deck = try #require(RevealAdapter().detect(try Fixtures.input("reveal.html")))
        // One unindexed fragment plus one shared index 2.
        #expect(deck.slides[3].builds.count == 2)
    }

    @Test func ignoresOtherFormats() throws {
        for name in ["demo-deck.html", "cue-convention.html", "marp-export.html"] {
            #expect(RevealAdapter().detect(try Fixtures.input(name)) == nil, "\(name)")
        }
    }
}
