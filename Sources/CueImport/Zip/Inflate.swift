import Compression
import Foundation

/// Raw DEFLATE (no zlib header), which is what ZIP stores.
/// Compression's `COMPRESSION_ZLIB` is exactly that.
enum Inflate {
    static func raw(_ compressed: Data, expectedSize: Int) throws -> Data {
        if expectedSize == 0 { return Data() }
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
        guard written == expectedSize else { throw ZipError.inflateFailed("deflate stream") }
        return output
    }
}
