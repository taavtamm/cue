import CueImport
import Foundation
import Testing
@testable import CueExport

@Suite("ZIP writer")
struct ZipWriterTests {
    @Test func cuesReaderReadsWhatItWrites() throws {
        var zip = ZipWriter()
        let big = Data(String(repeating: "deflate me ", count: 500).utf8)
        zip.add("a.xml", big)
        zip.add("media/pic.jpeg", Data([0xFF, 0xD8, 1, 2, 3]), compress: false)
        zip.add("ünïcode.txt", "hello")
        let archive = try ZipArchive(data: zip.data())
        #expect(archive.entries.map(\.path) == ["a.xml", "media/pic.jpeg", "ünïcode.txt"])
        #expect(try archive.data(for: "a.xml") == big)
        #expect(archive.entry("a.xml")?.method == 8, "text is deflated")
        #expect(archive.entry("media/pic.jpeg")?.method == 0, "pictures are stored")
        #expect(try archive.data(for: "ünïcode.txt") == Data("hello".utf8))
    }

    @Test func theSameInputGivesTheSameBytes() {
        var a = ZipWriter(), b = ZipWriter()
        a.add("x.xml", "<x/>"); b.add("x.xml", "<x/>")
        #expect(a.data() == b.data())
    }
}
