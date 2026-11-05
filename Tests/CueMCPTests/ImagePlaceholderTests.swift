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

    @Test func anUnknownPlaceholderIsRefused() {
        #expect(throws: (any Error).self) {
            try ImagePlaceholders.restore("<img src=\"data:image/png;base64,CUE-IMAGE-0000000000000000\">", from: Self.deck)
        }
    }
}
