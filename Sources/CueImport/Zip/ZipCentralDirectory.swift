import Foundation

/// Finds and walks the central directory, including ZIP64 records.
enum ZipCentralDirectory {
    struct Location {
        let offset: Int
        let size: Int
        let count: Int
    }

    private static let endSignature: UInt32 = 0x0605_4B50
    private static let zip64EndSignature: UInt32 = 0x0606_4B50
    private static let zip64LocatorSignature: UInt32 = 0x0706_4B50
    private static let entrySignature: UInt32 = 0x0201_4B50

    /// The end record sits in the last 64 KiB + 22 bytes (it may carry a comment).
    static func locate(in data: Data) throws -> Location {
        guard data.count >= 22 else { throw ZipError.notAZip }
        let lowest = max(0, data.count - 65_557)
        var end = data.count - 22
        while end >= lowest, data.uint32(at: end) != endSignature { end -= 1 }
        guard end >= lowest else { throw ZipError.notAZip }
        guard data.uint16(at: end + 4) == 0, data.uint16(at: end + 6) == 0 else { throw ZipError.multiDisk }

        var count = Int(data.uint16(at: end + 10))
        var size = Int(data.uint32(at: end + 12))
        var offset = Int(data.uint32(at: end + 16))
        if count == 0xFFFF || size == 0xFFFF_FFFF || offset == 0xFFFF_FFFF {
            let locator = end - 20
            guard locator >= 0, data.uint32(at: locator) == zip64LocatorSignature else { throw ZipError.truncated }
            let record = Int(data.uint64(at: locator + 8))
            guard record + 56 <= data.count, data.uint32(at: record) == zip64EndSignature else {
                throw ZipError.truncated
            }
            count = Int(data.uint64(at: record + 32))
            size = Int(data.uint64(at: record + 40))
            offset = Int(data.uint64(at: record + 48))
        }
        guard offset >= 0, size >= 0, offset + size <= data.count else { throw ZipError.truncated }
        return Location(offset: offset, size: size, count: count)
    }

    static func readEntries(in data: Data, at location: Location) throws -> [ZipEntry] {
        var entries: [ZipEntry] = []
        entries.reserveCapacity(location.count)
        var cursor = location.offset
        for _ in 0..<location.count {
            guard cursor + 46 <= data.count, data.uint32(at: cursor) == entrySignature else { throw ZipError.truncated }
            let nameLength = Int(data.uint16(at: cursor + 28))
            let extraLength = Int(data.uint16(at: cursor + 30))
            let commentLength = Int(data.uint16(at: cursor + 32))
            let nameStart = cursor + 46
            guard nameStart + nameLength + extraLength <= data.count else { throw ZipError.truncated }
            let nameBytes = data.subdata(in: nameStart..<nameStart + nameLength)
            let path = String(data: nameBytes, encoding: .utf8) ?? String(decoding: nameBytes, as: UTF8.self)

            var sizes = Zip64Sizes(
                uncompressed: UInt64(data.uint32(at: cursor + 24)),
                compressed: UInt64(data.uint32(at: cursor + 20)),
                offset: UInt64(data.uint32(at: cursor + 42))
            )
            sizes.applyExtra(data, from: nameStart + nameLength, length: extraLength)

            entries.append(ZipEntry(
                path: path,
                method: data.uint16(at: cursor + 10),
                flags: data.uint16(at: cursor + 8),
                crc32: data.uint32(at: cursor + 16),
                compressedSize: sizes.compressed,
                uncompressedSize: sizes.uncompressed,
                localHeaderOffset: sizes.offset
            ))
            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }
}

/// 32-bit sizes of 0xFFFFFFFF mean "see the ZIP64 extra field" (id 0x0001),
/// which lists only the fields that overflowed, in this order.
private struct Zip64Sizes {
    var uncompressed: UInt64
    var compressed: UInt64
    var offset: UInt64

    mutating func applyExtra(_ data: Data, from start: Int, length: Int) {
        var cursor = start
        let end = start + length
        while cursor + 4 <= end {
            let id = data.uint16(at: cursor)
            let size = Int(data.uint16(at: cursor + 2))
            var field = cursor + 4
            if id == 0x0001 {
                if uncompressed == 0xFFFF_FFFF, field + 8 <= end { uncompressed = data.uint64(at: field); field += 8 }
                if compressed == 0xFFFF_FFFF, field + 8 <= end { compressed = data.uint64(at: field); field += 8 }
                if offset == 0xFFFF_FFFF, field + 8 <= end { offset = data.uint64(at: field) }
            }
            cursor += 4 + size
        }
    }
}
