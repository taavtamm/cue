import Foundation

/// A fresh folder in the temporary directory, removed at the end of a test.
final class TempFolder {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("cue-import-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        try? FileManager.default.removeItem(at: url)
    }

    func file(_ name: String, _ data: Data) throws -> URL {
        let file = url.appendingPathComponent(name)
        try data.write(to: file)
        return file
    }

    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The first file with this extension in fixtures/private (git-ignored, for
    /// the developer's own real decks), or a path that doesn't exist.
    static func privateDeck(_ pathExtension: String) -> URL {
        let folder = repoRoot.appendingPathComponent("fixtures/private")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == pathExtension }.min { $0.lastPathComponent < $1.lastPathComponent }
            ?? folder.appendingPathComponent("missing.\(pathExtension)")
    }
}
