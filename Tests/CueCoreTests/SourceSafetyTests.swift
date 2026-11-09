import Foundation
import Testing
@testable import CueCore

/// Malformed selectors, attribute values and style text that used to crash
/// or produce broken markup.
@Suite("Source safety")
struct SourceSafetyTests {
    @Test func attributeSelectorsWithoutANameAreRejected() {
        #expect(SimpleSelector("div[]") == nil)
        #expect(SimpleSelector("[=x]") == nil)
        #expect(SimpleSelector("[ =x]") == nil)
        #expect(SimpleSelector("[data-x]") != nil)
        #expect(SimpleSelector(#"[data-x="1"]"#) != nil)
    }

    @Test func overrideSelectorsCannotCloseTheStyleBlock() throws {
        let html = "<html><head></head><body><section><h1>A</h1></section></body></html>"
        var document = try Editing.document(html: html)
        #expect(throws: EditError.self) {
            let selector = "h1</style><script>alert(1)</script>"
            return try document.apply(.setOverride(selector: selector, property: "color", value: "red"))
        }
        #expect(throws: EditError.self) {
            try document.apply(.setOverride(selector: "h1 <b", property: "color", value: "red"))
        }
        _ = try document.apply(.setOverride(selector: "section > h1", property: "color", value: "red"))
        #expect(document.source.contains("section > h1 { color: red; }"))
    }

    @Test func newAttributesGoAfterAnUnquotedValueEndingInASlash() throws {
        let html = "<html><body><section><a href=/docs/>Docs</a></section></body></html>"
        var document = try Editing.document(html: html)
        let link = try Editing.path(in: document, tag: "a")
        _ = try document.apply(.setAttribute(link, name: "title", value: "Docs"))
        #expect(document.source.contains(#"<a href=/docs/ title="Docs">Docs</a>"#))
    }

    @Test func newAttributesStillGoBeforeASelfClosingSlash() throws {
        var document = try Editing.document(html: #"<html><body><section><img src="a.png" /></section></body></html>"#)
        let image = try Editing.path(in: document, tag: "img")
        _ = try document.apply(.setAttribute(image, name: "alt", value: "A"))
        #expect(document.source.contains(#"<img src="a.png" alt="A" />"#))
    }

    @Test func innerTextUsesTheRealEndTag() throws {
        let html = "<html><head><script>var a = 1</script ></head><body></body></html>"
        let input = AdapterInput(root: try HTMLParser().parse(html), source: html)
        let script = try #require(input.root.first { $0.tag == "script" })
        #expect(input.innerText(of: script) == "var a = 1")
    }

    @Test func sanitizerKeepsEscapedQuotesInStyles() {
        let html = #"<span style="font-family: &quot;Inter&quot;, sans-serif; color: red">x</span>"#
        #expect(RichTextSanitizer.sanitize(html)
            == #"<span style="font-family: &quot;Inter&quot;, sans-serif; color: red;">x</span>"#)
        let unsafe = #"<span style="font-family: &quot;A;B&quot;; background: url(x)">y</span>"#
        #expect(RichTextSanitizer.sanitize(unsafe) == #"<span style="font-family: &quot;A;B&quot;;">y</span>"#)
    }

    @Test func copiesKeepEscapedQuotesInStyles() throws {
        let html = #"<p style="font-family: &quot;Inter&quot;, sans-serif; left: 3px">Hi</p>"#
        let frame = CGRect(x: 10, y: 20, width: 30, height: 40)
        let copy = try #require(ElementCopy.portable(html, frame: frame, newID: "n"))
        #expect(copy.contains("margin: 0; font-family: &quot;Inter&quot;, sans-serif;"))
        #expect(!copy.contains("left: 3px"))
    }
}

@Test func escapedURLsDontGetPastTheStyleFilter() {
    #expect(RichTextSanitizer.safeStyle("background: u&#114;l(https://x.example/a.png)") == nil)
    #expect(RichTextSanitizer.safeStyle("background: url&lpar;https://x.example/a.png)") == nil)
    #expect(RichTextSanitizer.safeStyle(#"background: \75rl(https://x.example/a.png)"#) == nil)
    #expect(RichTextSanitizer.safeStyle("font-family: &quot;Inter&quot;, sans-serif; color: red")
        == "font-family: &quot;Inter&quot;, sans-serif; color: red;")
}
