import Compression
import Foundation

/// Raw DEFLATE (no zlib header), which is what ZIP stores.
/// Compression's `COMPRESSION_ZLIB` is exactly that.
enum Inflate {
    /// Decodes into a buffer of exactly `expectedSize` bytes, so a stream that
    /// would expand further is cut off there (and then fails its CRC or the
    /// size check). The declared size is bounded by the compressed length
    /// first, so a lying header can't make Cue allocate a huge buffer.
    static func raw(_ compressed: Data, expectedSize: Int, path: String) throws -> Data {
        if expectedSize == 0 { return Data() }
        let (ceiling, overflow) = compressed.count.multipliedReportingOverflow(by: ZipLimits.maxDeflateRatio)
        guard overflow || expectedSize <= ceiling + 1024 else { throw ZipError.inflateFailed(path) }
        guard !compressed.isEmpty else { throw ZipError.inflateFailed(path) }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { destination in
            compressed.withUnsafeBytes { source in
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!, expectedSize,
                    source.bindMemory(to: UInt8.self).baseAddress!, compressed.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == expectedSize else { throw ZipError.inflateFailed(path) }
        return output
    }
}
