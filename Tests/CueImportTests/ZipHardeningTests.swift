import Foundation
import Testing
@testable import CueImport

/// Damaged or hostile archives fail with an error instead of trapping or
/// allocating whatever their headers claim.
@Suite("ZIP hardening")
struct ZipHardeningTests {
    private func archive(zip64: Bool, deflate: Bool = false,
                         _ files: [(String, Data)] = [("a.txt", Data("hello".utf8))]) -> Data {
        var writer = ZipWriter(options: .init(deflate: deflate, zip64: zip64))
        for (path, data) in files { writer.add(path, data) }
        return writer.data()
    }

    private func put(_ value: UInt64, bytes: Int, at offset: Int, in data: inout Data) {
        for i in 0..<bytes { data[offset + i] = UInt8(truncatingIfNeeded: value >> (8 * UInt64(i))) }
    }

    // ZIP64 layout from the end: zip64 record (56), locator (20), end record (22).
    private func zip64Record(_ data: Data) -> Int { data.count - 22 - 20 - 56 }
    /// Where the central directory starts (ZIP64 archives keep it in their own record).
    private func centralOffset(_ data: Data) -> Int {
        let classic = data.uint32(at: data.count - 22 + 16)
        return classic == 0xFFFF_FFFF ? Int(data.uint64(at: zip64Record(data) + 48)) : Int(classic)
    }
    /// The first entry's ZIP64 extra field: uncompressed, compressed, offset.
    private func extraField(_ data: Data, nameLength: Int = 5) -> Int { centralOffset(data) + 46 + nameLength + 4 }

    @Test func zip64RecordOffsetsBeyondIntAreTruncated() {
        var data = archive(zip64: true)
        put(UInt64.max, bytes: 8, at: data.count - 42 + 8, in: &data)
        #expect(throws: ZipError.truncated) { try ZipArchive(data: data) }
        put(UInt64(Int.max - 10), bytes: 8, at: data.count - 42 + 8, in: &data)
        #expect(throws: ZipError.truncated) { try ZipArchive(data: data) }
    }

    @Test func directoryOffsetsAndSizesThatOverflowAreTruncated() {
        var data = archive(zip64: true)
        put(UInt64.max, bytes: 8, at: zip64Record(data) + 48, in: &data)
        #expect(throws: ZipError.truncated) { try ZipArchive(data: data) }
        data = archive(zip64: true)
        put(UInt64(Int.max), bytes: 8, at: zip64Record(data) + 40, in: &data)
        #expect(throws: ZipError.truncated) { try ZipArchive(data: data) }
    }

    @Test func entryCountsTheDirectoryCanNotHoldAreTruncated() {
        var data = archive(zip64: true)
        put(1 << 40, bytes: 8, at: zip64Record(data) + 32, in: &data)
        #expect(throws: ZipError.truncated) { try ZipArchive(data: data) }
    }

    @Test func entryOffsetsAndSizesBeyondTheFileFailCleanly() throws {
        var data = archive(zip64: true)
        put(UInt64.max, bytes: 8, at: extraField(data) + 16, in: &data)
        #expect(throws: ZipError.badLocalHeader("a.txt")) { try ZipArchive(data: data).data(for: "a.txt") }
    }

    @Test func entrySizesBeyondTheFileFailCleanly() throws {
        var data = archive(zip64: true)
        put(UInt64.max - 1, bytes: 8, at: extraField(data) + 8, in: &data)
        #expect(throws: ZipError.truncated) { try ZipArchive(data: data).data(for: "a.txt") }
    }

    @Test func oversizedEntriesAreRefused() throws {
        var data = archive(zip64: true)
        put(ZipLimits.maxEntrySize + 1, bytes: 8, at: extraField(data), in: &data)
        let zip = try ZipArchive(data: data)
        #expect(throws: ZipError.tooLarge("a.txt")) { try zip.data(for: "a.txt") }
    }

    @Test func archivesDeclaringTooMuchInTotalAreRefused() {
        let files = (0..<5).map { ("f\($0).txt", Data("x".utf8)) }
        var data = archive(zip64: true, files)
        // Each central record: 46 + name (6) + extra (28).
        for index in 0..<5 {
            let field = centralOffset(data) + index * (46 + 6 + 28) + 46 + 6 + 4
            put(ZipLimits.maxEntrySize, bytes: 8, at: field, in: &data)
        }
        #expect(throws: ZipError.tooLarge("f4.txt")) { try ZipArchive(data: data) }
    }

    @Test func deflateBombsAreRefusedBeforeAllocating() throws {
        var data = archive(zip64: false, deflate: true)
        put(100 * 1024 * 1024, bytes: 4, at: centralOffset(data) + 24, in: &data)
        let zip = try ZipArchive(data: data)
        #expect(throws: ZipError.inflateFailed("a.txt")) { try zip.data(for: "a.txt") }
    }

    @Test func highlyCompressedButHonestEntriesStillRead() throws {
        let zeros = Data(count: 4 * 1024 * 1024)
        let zip = try ZipArchive(data: archive(zip64: false, deflate: true, [("zeros", zeros)]))
        #expect(try zip.data(for: "zeros") == zeros)
    }
}
