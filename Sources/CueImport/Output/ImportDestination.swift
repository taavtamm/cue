import Foundation

/// Where an import is written: `<Name> (Cue).html` and `<Name> assets/` next
/// to the original, or in ~/Documents/Cue Imports/ when that folder is
/// read-only. Cue only ever replaces files it wrote itself.
public struct ImportDestination: Sendable, Equatable {
    public let htmlURL: URL
    public let assetsURL: URL
    /// True when the output couldn't go next to the original.
    public let isRelocated: Bool

    static let marker = ".cue-import"

    public static func choose(for source: URL, fallbackFolder: URL? = nil) -> ImportDestination {
        let fileManager = FileManager.default
        let name = source.deletingPathExtension().lastPathComponent
        var folder = source.deletingLastPathComponent()
        var relocated = false
        if !fileManager.isWritableFile(atPath: folder.path) {
            folder = fallbackFolder ?? Self.defaultFallback
            relocated = true
        }
        var suffix = 1
        while true {
            let tag = suffix == 1 ? "Cue" : "Cue \(suffix)"
            let html = folder.appendingPathComponent("\(name) (\(tag)).html")
            let assets = folder.appendingPathComponent("\(name) (\(tag)) assets", isDirectory: true)
            let htmlFree = !fileManager.fileExists(atPath: html.path) || isCueOutput(html)
            let assetsFree = !fileManager.fileExists(atPath: assets.path) || isCueAssets(assets)
            if htmlFree && assetsFree {
                return ImportDestination(htmlURL: html, assetsURL: assets, isRelocated: relocated)
            }
            suffix += 1
        }
    }

    public static var defaultFallback: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cue Imports", isDirectory: true)
    }

    /// Cue's own import output carries `<meta name="cue:imported-from">` near the top.
    public static func isCueOutput(_ html: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: html) else { return false }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: 4096)) ?? Data()
        return String(decoding: head, as: UTF8.self).contains("name=\"cue:imported-from\"")
    }

    static func isCueAssets(_ folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(marker).path)
    }

    public var exists: Bool { FileManager.default.fileExists(atPath: htmlURL.path) }

    /// Replaces Cue's previous output (if any) with the new deck.
    func write(html: String, assets: AssetStore) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: htmlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: assetsURL.path) {
            guard Self.isCueAssets(assetsURL) else { throw ImportError.wouldOverwrite(assetsURL) }
            try fileManager.removeItem(at: assetsURL)
        }
        if !assets.isEmpty {
            try assets.write(to: assetsURL)
            try Data().write(to: assetsURL.appendingPathComponent(Self.marker))
        }
        if fileManager.fileExists(atPath: htmlURL.path), !Self.isCueOutput(htmlURL) {
            throw ImportError.wouldOverwrite(htmlURL)
        }
        try Data(html.utf8).write(to: htmlURL, options: .atomic)
    }
}
