import Foundation
import Testing
@testable import CueImport

/// Mixed-content text order and number formatting on damaged input.
@Suite("Import text")
struct ImportTextTests {
    private func paragraph(_ inner: String) throws -> XNode {
        let namespace = "urn:oasis:names:tc:opendocument:xmlns:text:1.0"
        let xml = #"<frame xmlns:text="\#(namespace)"><text:p>\#(inner)</text:p></frame>"#
        return try XMLTreeParser.parse(Data(xml.utf8))
    }

    @Test func textAroundSpansKeepsItsOrder() throws {
        let frame = try paragraph("Hello <text:span>big</text:span> world")
        #expect(ODPText.plain(frame) == "Hello big world")
        let html = ODPText.html(frame, styles: ODPTextStyles(nil))
        #expect(html.contains(#"Hello <span style="">big</span> world"#))
    }

    @Test func lineBreaksAndSpacesSitWhereTheyWere() throws {
        let frame = try paragraph(#"One<text:line-break/>Two<text:s text:c="3"/>Three"#)
        #expect(ODPText.html(frame, styles: ODPTextStyles(nil)).contains("One<br>Two   Three"))
        #expect(ODPText.plain(frame) == "One\nTwo   Three")
    }

    @Test func spaceCountsAreKeptSane() throws {
        let negative = try paragraph(#"a<text:s text:c="-5"/>b"#)
        #expect(ODPText.html(negative, styles: ODPTextStyles(nil)).contains(">ab<"))
        let huge = try paragraph(#"a<text:s text:c="999999999"/>b"#)
        let html = ODPText.html(huge, styles: ODPTextStyles(nil))
        #expect(html.contains("a" + String(repeating: " ", count: 1000) + "b"))
    }

    @Test func cssNumbersSurviveNonFiniteAndHugeValues() {
        #expect(css(.nan) == "0")
        #expect(css(.infinity) == "0")
        #expect(css(-.infinity) == "0")
        #expect(css(1e300) == "1000000px")
        #expect(css(-1e300) == "-1000000px")
        #expect(css(12.345) == "12.35px")
        #expect(css(3) == "3px")
    }
}
