import Foundation

/// Reads a ZIP archive (PowerPoint, Keynote and OpenDocument files are ZIPs).
/// Entries come from the central directory, so local data descriptors don't
/// matter. Stored and deflated entries are supported, including ZIP64.
public struct ZipArchive: Sendable {
    public let entries: [ZipEntry]
    private let data: Data
    private let byPath: [String: Int]

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .alwaysMapped))
    }

    public init(data: Data) throws {
        self.data = data
        let directory = try ZipCentralDirectory.locate(in: data)
        entries = try ZipCentralDirectory.readEntries(in: data, at: directory)
        var index: [String: Int] = [:]
        for (i, entry) in entries.enumerated() where index[entry.path] == nil { index[entry.path] = i }
        byPath = index
    }

    public func entry(_ path: String) -> ZipEntry? {
        byPath[path].map { entries[$0] }
    }

    public func contains(_ path: String) -> Bool { byPath[path] != nil }

    /// The uncompressed bytes of `path`, CRC-checked.
    public func data(for path: String) throws -> Data {
        guard let entry = entry(path) else { throw ZipError.missingEntry(path) }
        return try data(for: entry)
    }

    public func data(for entry: ZipEntry) throws -> Data {
        if entry.isEncrypted { throw ZipError.encrypted(entry.path) }
        let start = try localDataOffset(of: entry)
        let (end, overflow) = start.addingReportingOverflow(Int(clamping: entry.compressedSize))
        guard !overflow, end <= data.count else { throw ZipError.truncated }
        let raw = data.subdata(in: start..<end)
        let bytes: Data
        switch entry.method {
        case 0: bytes = raw
        case 8: bytes = try Inflate.raw(raw, expectedSize: Int(entry.uncompressedSize))
        default: throw ZipError.unsupportedMethod(entry.method, entry.path)
        }
        guard CRC32.checksum(bytes) == entry.crc32 else { throw ZipError.checksumMismatch(entry.path) }
        return bytes
    }

    public func string(for path: String) throws -> String {
        let bytes = try data(for: path)
        guard let text = String(data: bytes, encoding: .utf8) else { throw ZipError.notText(path) }
        return text
    }

    /// The local header has its own name and extra lengths; data follows them.
    private func localDataOffset(of entry: ZipEntry) throws -> Int {
        let header = Int(entry.localHeaderOffset)
        guard header + 30 <= data.count, data.uint32(at: header) == 0x0403_4B50 else {
            throw ZipError.badLocalHeader(entry.path)
        }
        return header + 30 + Int(data.uint16(at: header + 26)) + Int(data.uint16(at: header + 28))
    }
}
