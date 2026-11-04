import Testing
@testable import CueCore

@Suite("Claude Design adapter")
struct ClaudeDesignAdapterTests {
    static let demoDeckLabels = [
        "Plans that hold up.",
        "Your team already keeps notes in ten places.",
        "One question, answered.",
        "It has read every note you already keep.",
        "Three layers of memory.",
        "From a question to a board the whole crew uses.",
        "Any chore, done as the person who asked.",
        "Any till. Any app. Your pick, and you can switch later.",
        "Your login. Your access rules. Your hardware. Your data. Everything logged.",
        "Same app, same promises.",
        "One plan, three headaches gone.",
        "A 30-day trial.",
    ]

    @Test func detectsTheFixtureDeck() throws {
        let deck = try Fixtures.structure("demo-deck.html")
        #expect(deck.adapter == .claudeDesign)
        #expect(deck.renderMode == .cueDriven)
        #expect(deck.canvas == CanvasSize(width: 1920, height: 1080))
        #expect(deck.slides.count == 12)
        #expect(deck.slides.map(\.label) == Self.demoDeckLabels)
        #expect(deck.slides.map(\.id) == (1...12).map(String.init))
    }

    @Test func prefersLabelledContainerOverDeclaredCanvasSelector() throws {
        // hz:slide-selector ".slide" names the canvas div inside each section.deck-slide.
        let deck = try Fixtures.structure("demo-deck.html")
        #expect(deck.slideSelector == ".deck-slide")
    }

    @Test func usesDeclaredSelectorWhenNoContainer() throws {
        let html = """
        <html><head><meta name="hz:slide-selector" content=".page"></head>
        <body><div class="page" data-label="P1"></div><div class="page"><h1>P2</h1></div></body></html>
        """
        let input = AdapterInput(root: try HTMLParser().parse(html), source: html)
        let deck = try #require(ClaudeDesignAdapter().detect(input))
        #expect(deck.slideSelector == ".page")
        #expect(deck.slides.map(\.label) == ["P1", "P2"])
    }

    @Test func readsNotesFromSpeakerNotesAttribute() throws {
        let deck = try Fixtures.structure("demo-deck.html")
        #expect(deck.slides[0].notes.hasPrefix("Everything on these slides runs on the shop’s own setup"))
        #expect(deck.slides.allSatisfy { !$0.notes.isEmpty })
    }

    @Test func liveContentComesFromDeckMotionEmbeds() throws {
        let deck = try Fixtures.structure("demo-deck.html")
        let live = deck.slides.map(\.hasLiveContent)
        #expect(live == [true, true, true, true, true, true, true, false, true, true, true, true])
        #expect(deck.slides.allSatisfy { $0.builds.isEmpty })
    }

    @Test func playerScriptRangeCoversTheInlinePlayer() throws {
        let input = try Fixtures.input("demo-deck.html")
        let deck = try #require(ClaudeDesignAdapter().detect(input))
        let script = input.text(in: try #require(deck.replacedPlayerScript))
        #expect(script.hasPrefix("<script>"))
        #expect(script.hasSuffix("</script>"))
        #expect(script.contains(#"getElementById("deck-motion")"#))
        #expect(!script.contains("application/json"))
    }

    @Test func slideRangesStartAtTheirSections() throws {
        let input = try Fixtures.input("demo-deck.html")
        let deck = try #require(ClaudeDesignAdapter().detect(input))
        for slide in deck.slides {
            let text = input.text(in: try #require(slide.sourceRange))
            #expect(text.hasPrefix(#"<section class="deck-slide" id="\#(slide.id)""#))
        }
    }

    @Test func buildsAndCanvasFromSmallDeck() throws {
        let deck = try #require(ClaudeDesignAdapter().detect(try Fixtures.input("misleading-hz-meta.html")))
        #expect(deck.canvas == CanvasSize(width: 1600, height: 900))
        #expect(deck.slides.map(\.label) == ["Alpha", "Beta"])
        #expect(deck.slides[0].builds == [BuildStep(targets: [#"[data-frame-id="f1"]"#], effect: "rise")])
        #expect(deck.slides.map(\.hasLiveContent) == [false, true])
        #expect(deck.replacedPlayerScript != nil)
    }

    @Test func ignoresOtherFormats() throws {
        for name in ["reveal.html", "cue-convention.html", "plain-page.html", "sections.html"] {
            #expect(ClaudeDesignAdapter().detect(try Fixtures.input(name)) == nil, "\(name)")
        }
    }
}
