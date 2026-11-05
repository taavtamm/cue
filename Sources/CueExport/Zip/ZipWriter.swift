import Compression
import CueImport
import Foundation

/// Writes a ZIP archive (what .pptx files are): deflated entries, written
/// in the order added. Small and strict: no ZIP64 (exports stay well under
/// 4 GB), no encryption, UTF-8 names.
public struct ZipWriter: Sendable {
    private var entries: [(name: String, data: Data, deflate: Bool)] = []

    public init() {}

    /// Adds a file. Already-compressed data (PNG, JPEG) is stored as is.
    public mutating func add(_ path: String, _ data: Data, compress: Bool = true) {
        entries.append((path, data, compress))
    }

    public mutating func add(_ path: String, _ text: String) { add(path, Data(text.utf8)) }

    public var paths: [String] { entries.map(\.name) }

    public func data() -> Data {
        var out = Data(), central = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            let deflated = entry.deflate ? Self.deflate(entry.data) : nil
            let body = deflated ?? entry.data
            let method: UInt16 = deflated == nil ? 0 : 8
            let crc = CRC32.checksum(entry.data)
            let offset = UInt32(out.count)
            let utf8: UInt16 = 0x0800
            out.append(le32(0x0403_4B50) + le16(20) + le16(utf8) + le16(method) + le32(Self.dosTime))
            out.append(le32(crc) + le32(UInt32(body.count)) + le32(UInt32(entry.data.count)))
            out.append(le16(UInt16(name.count)) + le16(0) + name + body)
            central.append(le32(0x0201_4B50) + le16(20) + le16(20) + le16(utf8) + le16(method) + le32(Self.dosTime))
            central.append(le32(crc) + le32(UInt32(body.count)) + le32(UInt32(entry.data.count)))
            central.append(le16(UInt16(name.count)) + le16(0) + le16(0) + le16(0) + le16(0) + le32(0) + le32(offset))
            central.append(name)
        }
        let centralOffset = UInt32(out.count)
        out.append(central)
        out.append(le32(0x0605_4B50) + le16(0) + le16(0) + le16(UInt16(entries.count)) + le16(UInt16(entries.count)))
        out.append(le32(UInt32(central.count)) + le32(centralOffset) + le16(0))
        return out
    }

    /// 2026-01-01 00:00, a fixed time so the same deck exports byte for byte the same.
    static let dosTime: UInt32 = (UInt32(2026 - 1980) << 25) | (1 << 21) | (1 << 16)

    /// Raw DEFLATE (what ZIP stores), or nil when it doesn't make the data smaller.
    static func deflate(_ data: Data) -> Data? {
        guard data.count > 64 else { return nil }
        let capacity = data.count + 1024
        var output = Data(count: capacity)
        let size = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compression_encode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, capacity,
                    source.bindMemory(to: UInt8.self).baseAddress!, data.count, nil, COMPRESSION_ZLIB
                )
            }
        }
        guard size > 0, size < data.count else { return nil }
        return output.prefix(size)
    }
}

private func le16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
private func le32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
