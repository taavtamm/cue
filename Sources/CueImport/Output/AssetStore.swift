import Foundation

/// Collects pictures for the `<Name> assets/` folder. The same source part
/// is stored once, under a short readable name.
public final class AssetStore: @unchecked Sendable {
    public let folderName: String
    private(set) var files: [(name: String, data: Data)] = []
    private var nameForKey: [String: String] = [:]

    public init(folderName: String) {
        self.folderName = folderName
    }

    /// Adds `data` (once per `key`) and returns the relative URL to use in HTML.
    public func add(_ data: Data, key: String, preferredName: String) -> String {
        if let existing = nameForKey[key] { return url(for: existing) }
        let name = uniqueName(preferredName)
        files.append((name, data))
        nameForKey[key] = name
        return url(for: name)
    }

    public var isEmpty: Bool { files.isEmpty }

    func write(to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in files {
            try file.data.write(to: folder.appendingPathComponent(file.name), options: .atomic)
        }
    }

    private func url(for name: String) -> String { HTMLText.urlPath([folderName, name]) }

    private func uniqueName(_ preferred: String) -> String {
        let clean = preferred.replacingOccurrences(of: "/", with: "-")
        let base = (clean as NSString).deletingPathExtension
        let ext = (clean as NSString).pathExtension
        var candidate = clean
        var n = 2
        while files.contains(where: { $0.name == candidate }) {
            candidate = ext.isEmpty ? "\(base)-\(n)" : "\(base)-\(n).\(ext)"
            n += 1
        }
        return candidate
    }
}
