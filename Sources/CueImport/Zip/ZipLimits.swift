import Foundation

/// Bounds on what a ZIP may make Cue allocate. Sizes in the archive are
/// declared by whoever wrote it, so they are checked before they are trusted.
public enum ZipLimits {
    /// The largest single entry Cue will decompress.
    public static let maxEntrySize: UInt64 = 512 * 1024 * 1024
    /// The largest total of all entries' declared uncompressed sizes.
    public static let maxTotalSize: UInt64 = 2 * 1024 * 1024 * 1024
    /// Every central-directory record is at least this long.
    static let minDirectoryRecord = 46
    /// DEFLATE can't expand by more than about 1032:1, so a declared size far
    /// beyond that is a lie and is rejected before allocating for it.
    static let maxDeflateRatio = 1032
}
