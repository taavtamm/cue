import Foundation

/// The decks shown on the Welcome window: most recent first, without
/// duplicates or files that have since been moved or deleted.
public enum RecentDecks {
    public static func pruned(
        _ urls: [URL], limit: Int = 12, exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls where result.count < limit {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path), exists(url) else { continue }
            seen.insert(path)
            result.append(url)
        }
        return result
    }
}

/// The cache file name for a deck's Welcome thumbnail. It changes whenever
/// the deck's path or modification date does, so an edited deck is drawn
/// again and an unchanged one never is.
public struct ThumbnailCacheKey: Sendable, Hashable {
    public let fileName: String

    public init(url: URL, modified: Date) {
        let seed = "\(url.standardizedFileURL.path)|\(modified.timeIntervalSince1970)"
        fileName = String(format: "%016llx", Self.fnv1a(seed)) + ".png"
    }

    /// Reads the modification date from disk. Nil when the file is gone.
    /// (FileManager, not `URL.resourceValues`, which caches per URL.)
    public init?(fileAt url: URL) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let modified = attributes?[.modificationDate] as? Date else { return nil }
        self.init(url: url, modified: modified)
    }

    /// FNV-1a, 64-bit: stable across launches, unlike `hashValue`.
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
