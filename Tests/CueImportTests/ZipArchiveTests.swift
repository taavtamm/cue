import Foundation
import Testing
@testable import CueImport

@Suite("ZIP reader")
struct ZipArchiveTests {
    private func roundTrip(_ options: ZipWriter.Options) throws {
        var writer = ZipWriter(options: options)
        writer.add("a.txt", "hello")
        writer.add("folder/b.xml", String(repeating: "<x>deflate me</x>", count: 200))
        writer.add("empty", Data())
        let zip = try ZipArchive(data: writer.data())
        #expect(zip.entries.map(\.path) == ["a.txt", "folder/b.xml", "empty"])
        #expect(try zip.string(for: "a.txt") == "hello")
        #expect(try zip.string(for: "folder/b.xml").count == 17 * 200)
        #expect(try zip.data(for: "empty").isEmpty)
    }

    @Test func readsStoredEntries() throws { try roundTrip(.init(deflate: false)) }
    @Test func readsDeflatedEntries() throws { try roundTrip(.init(deflate: true)) }
    @Test func readsEntriesWithDataDescriptors() throws { try roundTrip(.init(dataDescriptors: true)) }
    @Test func readsZip64Records() throws { try roundTrip(.init(zip64: true)) }

    @Test func rejectsFilesThatAreNotZips() {
        #expect(throws: ZipError.notAZip) { try ZipArchive(data: Data("not a zip at all, just text".utf8)) }
    }

    @Test func detectsCorruptedData() throws {
        var writer = ZipWriter(options: .init(deflate: false))
        writer.add("a.txt", "hello world")
        var bytes = writer.data()
        let index = try #require(bytes.firstRange(of: Data("hello".utf8))).lowerBound
        bytes[index] = UInt8(ascii: "j")
        let zip = try ZipArchive(data: bytes)
        #expect(throws: ZipError.checksumMismatch("a.txt")) { try zip.data(for: "a.txt") }
    }

    @Test func reportsMissingEntries() throws {
        var writer = ZipWriter()
        writer.add("a", "x")
        let zip = try ZipArchive(data: writer.data())
        #expect(throws: ZipError.missingEntry("b")) { try zip.data(for: "b") }
    }
}
