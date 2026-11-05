import Foundation
import Testing
@testable import CueMCP

@Suite("Image placeholders")
struct ImagePlaceholderTests {
    static let image = String(repeating: "QUJD", count: 1_000) // 4 000 base64 characters.
    static let deck = #"<section><img src="data:image/png;base64,\#(image)"><h1>Title</h1></section>"#

    @Test func largeImagesBecomePlaceholdersAndComeBack() throws {
        let short = ImagePlaceholders.shorten(Self.deck)
        #expect(!short.contains(Self.image))
        #expect(short.contains("data:image/png;base64,CUE-IMAGE-"))
        #expect(short.contains("<h1>Title</h1>"))
        // Claude rewrites the slide, keeping the placeholder.
        let rewritten = short.replacingOccurrences(of: "Title", with: "New title")
        let restored = try ImagePlaceholders.restore(rewritten, from: Self.deck)
        #expect(restored == Self.deck.replacingOccurrences(of: "Title", with: "New title"))
    }

    @Test func smallImagesStayAsTheyAre() {
        let small = #"<img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=">"#
        #expect(ImagePlaceholders.shorten(small) == small)
    }

    /// A megabyte-sized screenshot, as real decks have: the scan must still
    /// find it (ICU's regex overflowed and silently matched nothing).
    @Test func aMegabyteImageBecomesAPlaceholder() throws {
        let big = String(repeating: "iVBO", count: 260_000)
        let deck = #"<img src="data:image/png;base64,\#(big)" alt="x"><p>Text</p>"#
        let short = ImagePlaceholders.shorten(deck)
        #expect(short.count < 200)
        #expect(short.contains("CUE-IMAGE-") && short.contains("<p>Text</p>"))
        #expect(try ImagePlaceholders.restore(short, from: deck) == deck)
    }

    @Test func base64OutsideADataURIStaysAsItIs() {
        let text = "<p>;base64," + String(repeating: "A", count: 3_000) + "</p>"
        #expect(ImagePlaceholders.shorten(text) == text)
    }

    @Test func anUnknownPlaceholderIsRefused() {
        #expect(throws: (any Error).self) {
            try ImagePlaceholders.restore("<img src=\"data:image/png;base64,CUE-IMAGE-0000000000000000\">", from: Self.deck)
        }
    }
}
