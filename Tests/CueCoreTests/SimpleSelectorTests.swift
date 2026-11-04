import Testing
@testable import CueCore

@Suite("SimpleSelector")
struct SimpleSelectorTests {
    let root: HTMLNode

    init() throws {
        root = try HTMLParser().parse("""
        <html><body>
          <div class="deck"><section class="slide a" id="one" data-x="1"></section>
          <div><section class="slide"></section></div></div>
          <section class="loose"></section>
        </body></html>
        """)
    }

    private func count(_ selector: String) -> Int? {
        SimpleSelector(selector)?.matches(in: root).count
    }

    @Test func compoundSelectors() {
        #expect(count("section") == 3)
        #expect(count(".slide") == 2)
        #expect(count("section.slide.a") == 1)
        #expect(count("#one") == 1)
        #expect(count("[data-x]") == 1)
        #expect(count(#"[data-x="1"]"#) == 1)
        #expect(count(#"[data-x="2"]"#) == 0)
    }

    @Test func combinators() {
        #expect(count(".deck section") == 2)
        #expect(count(".deck > section") == 1)
        #expect(count(".deck>section") == 1)
        #expect(count("body > section") == 1)
        #expect(count(".deck > div > section") == 1)
    }

    @Test func commaListsKeepDocumentOrder() throws {
        let matches = try #require(SimpleSelector(".loose, #one")?.matches(in: root))
        #expect(matches.map { $0.node["id"] ?? $0.node["class"] } == ["one", "loose"])
    }

    @Test func unsupportedSyntaxFailsToParse() {
        #expect(SimpleSelector("section:not(.a)") == nil)
        #expect(SimpleSelector("a ~ b") == nil)
        #expect(SimpleSelector("") == nil)
    }
}
