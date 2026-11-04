import Compression
import Foundation
@testable import CueImport

/// Writes small ZIP archives for tests: stored or deflated entries,
/// optional data descriptors, optional ZIP64 records.
struct ZipWriter {
    struct Options {
        var deflate = true
        var dataDescriptors = false
        var zip64 = false
    }

    var options = Options()
    private var entries: [(String, Data)] = []

    init(options: Options = Options()) { self.options = options }

    mutating func add(_ path: String, _ data: Data) { entries.append((path, data)) }
    mutating func add(_ path: String, _ text: String) { add(path, Data(text.utf8)) }

    func data() -> Data {
        var out = Data(), central = Data()
        for (path, raw) in entries {
            let name = Data(path.utf8)
            let compressed = options.deflate ? Self.deflate(raw) : raw
            let method: UInt16 = options.deflate ? 8 : 0
            let crc = CRC32.checksum(raw)
            let offset = UInt32(out.count)
            let flags: UInt16 = options.dataDescriptors ? 0x0008 : 0
            out.append(le32(0x0403_4B50)); out.append(le16(20)); out.append(le16(flags)); out.append(le16(method))
            out.append(le32(0))
            out.append(le32(options.dataDescriptors ? 0 : crc))
            out.append(le32(options.dataDescriptors ? 0 : UInt32(compressed.count)))
            out.append(le32(options.dataDescriptors ? 0 : UInt32(raw.count)))
            out.append(le16(UInt16(name.count))); out.append(le16(0)); out.append(name); out.append(compressed)
            if options.dataDescriptors {
                out.append(le32(0x0807_4B50)); out.append(le32(crc))
                out.append(le32(UInt32(compressed.count))); out.append(le32(UInt32(raw.count)))
            }
            let extra = options.zip64
                ? le16(1) + le16(24) + le64(UInt64(raw.count)) + le64(UInt64(compressed.count)) + le64(UInt64(offset))
                : Data()
            let big: UInt32 = 0xFFFF_FFFF
            central.append(le32(0x0201_4B50)); central.append(le16(45)); central.append(le16(45))
            central.append(le16(flags)); central.append(le16(method)); central.append(le32(0)); central.append(le32(crc))
            central.append(le32(options.zip64 ? big : UInt32(compressed.count)))
            central.append(le32(options.zip64 ? big : UInt32(raw.count)))
            central.append(le16(UInt16(name.count))); central.append(le16(UInt16(extra.count))); central.append(le16(0))
            central.append(le16(0)); central.append(le16(0)); central.append(le32(0))
            central.append(le32(options.zip64 ? big : offset)); central.append(name); central.append(extra)
        }
        let centralOffset = out.count
        out.append(central)
        if options.zip64 {
            let record = out.count
            out.append(le32(0x0606_4B50)); out.append(le64(44)); out.append(le16(45)); out.append(le16(45))
            out.append(le32(0)); out.append(le32(0))
            out.append(le64(UInt64(entries.count))); out.append(le64(UInt64(entries.count)))
            out.append(le64(UInt64(central.count))); out.append(le64(UInt64(centralOffset)))
            out.append(le32(0x0706_4B50)); out.append(le32(0)); out.append(le64(UInt64(record))); out.append(le32(1))
        }
        out.append(le32(0x0605_4B50)); out.append(le16(0)); out.append(le16(0))
        let count: UInt16 = options.zip64 ? 0xFFFF : UInt16(entries.count)
        out.append(le16(count)); out.append(le16(count))
        out.append(le32(options.zip64 ? 0xFFFF_FFFF : UInt32(central.count)))
        out.append(le32(options.zip64 ? 0xFFFF_FFFF : UInt32(centralOffset)))
        out.append(le16(0))
        return out
    }

    static func deflate(_ data: Data) -> Data {
        if data.isEmpty { return Data() }
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
        return output.prefix(size)
    }
}

private func le16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
private func le32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
private func le64(_ value: UInt64) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
