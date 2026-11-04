import Foundation

/// One file in a ZIP archive, as its central directory describes it.
public struct ZipEntry: Sendable, Equatable {
    public let path: String
    public let method: UInt16
    public let flags: UInt16
    public let crc32: UInt32
    public let compressedSize: UInt64
    public let uncompressedSize: UInt64
    public let localHeaderOffset: UInt64

    public var isDirectory: Bool { path.hasSuffix("/") }
    public var isEncrypted: Bool { flags & 1 != 0 }
}
