import Testing
@testable import CueCore

@Suite("Cue convention adapter")
struct CueConventionAdapterTests {
    @Test func detectsSlidesNotesAndBuilds() throws {
        let deck = try #require(CueConventionAdapter().detect(try Fixtures.input("cue-convention.html")))
        #expect(deck.adapter == .cue)
        #expect(deck.renderMode == .cueDriven)
        #expect(deck.canvas == CanvasSize(width: 1280, height: 720))
        #expect(deck.slideSelector == "[data-cue-slide]")
        #expect(deck.slides.map(\.label) == ["Hello, Cue", "Three points", "Demo"])
        #expect(deck.slides.map(\.id) == ["intro", "slide-2", "slide-3"])
        #expect(deck.slides[0].notes == "Say hello.")
        #expect(deck.slides[1].notes == "Pause after each point.")
    }

    @Test func groupsBuildsByStep() throws {
        let deck = try #require(CueConventionAdapter().detect(try Fixtures.input("cue-convention.html")))
        let builds = deck.slides[1].builds
        #expect(builds.count == 3)
        #expect(builds[0] == BuildStep(targets: [#"[data-cue-build="1"]"#], effect: "rise"))
        #expect(builds[1].targets == [#"[data-cue-build="2"]"#])
        #expect(deck.slides[1].stateCount == 4)
    }

    @Test func detectsLiveContent() throws {
        let deck = try #require(CueConventionAdapter().detect(try Fixtures.input("cue-convention.html")))
        #expect(deck.slides.map(\.hasLiveContent) == [false, false, true])
    }

    @Test func ignoresOtherFormats() throws {
        for name in ["demo-deck.html", "reveal.html", "plain-page.html"] {
            #expect(CueConventionAdapter().detect(try Fixtures.input(name)) == nil, "\(name)")
        }
    }
}
