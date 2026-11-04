import Foundation
import Testing
@testable import CueCore

@Suite("HTMLParser")
struct HTMLParserTests {
    @Test func elementRangesSliceBackToSource() throws {
        let html = #"<!doctype html><html><head><title>T</title></head>"#
            + #"<body><p class="a" id="x">Hi <b>there</b></p></body></html>"#
        let input = AdapterInput(root: try HTMLParser().parse(html), source: html)
        let paragraph = try #require(input.root.first { $0.tag == "p" })
        #expect(input.text(in: try #require(paragraph.range)) == #"<p class="a" id="x">Hi <b>there</b></p>"#)
        #expect(input.text(in: try #require(paragraph.startTagRange)) == #"<p class="a" id="x">"#)
        #expect(input.text(in: try #require(paragraph.attributeRanges["id"])) == #"id="x""#)
        #expect(paragraph.text == "Hi")
    }

    @Test func offsetsAreUTF16() throws {
        let html = "<html><body><p>🎉é</p><span id=\"after\">x</span></body></html>"
        let input = AdapterInput(root: try HTMLParser().parse(html), source: html)
        let span = try #require(input.root.first { $0.tag == "span" })
        #expect(input.text(in: try #require(span.range)) == #"<span id="after">x</span>"#)
    }

    @Test func headingsCarryDeepText() throws {
        let root = try HTMLParser().parse("<html><body><h1>Big <em>news</em> today</h1></body></html>")
        #expect(root.first { $0.tag == "h1" }?.text == "Big news today")
    }

    @Test func scriptsAreNotExecuted() throws {
        // parse5 treats script bodies as text; this would throw if evaluated.
        let root = try HTMLParser().parse("<html><body><script>throw new Error('ran')</script></body></html>")
        #expect(root.first { $0.tag == "script" } != nil)
    }

    @Test func fixtureDeckParsesQuickly() throws {
        let source = try Fixtures.source("demo-deck.html")
        let parser = try HTMLParser()
        let start = Date()
        let root = try parser.parse(source)
        let seconds = Date().timeIntervalSince(start)
        let jit = JITProbe.isAvailable
        print("demo-deck.html parse: \(String(format: "%.3f", seconds)) s, JIT \(jit ? "on" : "off")")
        #expect(root.tag == "html")
        // The app ships with the allow-jit entitlement (~0.05 s). `swift test`
        // runs unentitled, where JavaScriptCore interprets (~1.3 s).
        #expect(seconds < (jit ? 1.0 : 4.0))
    }
}
