import CoreServices
import Foundation

/// Asks Keynote to save a PowerPoint copy of a .key, .ppt or .odp file.
/// Runs `osascript` so a slow or stuck Keynote can be timed out; macOS asks
/// the user once whether Cue may control Keynote.
public struct KeynoteExporter: Sendable {
    public static let bundleID = "com.apple.Keynote"
    public var timeout: Duration
    /// Which app counts as Keynote; tests swap in one that doesn't exist.
    var bundleID: String

    public init(timeout: Duration = .seconds(180)) {
        self.timeout = timeout
        bundleID = Self.bundleID
    }

    /// An exporter that behaves as if Keynote isn't installed.
    public static var unavailable: KeynoteExporter {
        var exporter = KeynoteExporter()
        exporter.bundleID = "app.cue.no-such-keynote"
        return exporter
    }

    /// Found by bundle id, whatever the app is called ("Keynote", "Keynote Creator Studio").
    public var appURL: URL? {
        let urls = LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL]
        return urls?.first
    }

    public var isInstalled: Bool { appURL != nil }

    /// Returns a temporary .pptx; the caller deletes its folder.
    public func exportPowerPoint(from source: URL) async throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cue-keynote-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let output = folder.appendingPathComponent(source.deletingPathExtension().lastPathComponent + ".pptx")
        let result = try await OSAScriptRunner.run(Self.script, arguments: [source.path, output.path], timeout: timeout)
        guard result.status == 0 else {
            try? FileManager.default.removeItem(at: folder)
            if result.errorText.contains("-1743") { throw ImportError.automationDenied }
            throw ImportError.keynoteFailed(result.errorText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard FileManager.default.fileExists(atPath: output.path) else {
            throw ImportError.keynoteFailed("no file was written")
        }
        return output
    }

    /// Opens, exports and closes without saving; quits Keynote only if Cue started it.
    static let script = """
        on run argv
          set sourceFile to POSIX file (item 1 of argv)
          set targetFile to POSIX file (item 2 of argv)
          set wasRunning to application id "com.apple.Keynote" is running
          tell application id "com.apple.Keynote"
            set theDocument to open sourceFile
            export theDocument to targetFile as Microsoft PowerPoint
            close theDocument saving no
            if not wasRunning then quit saving no
          end tell
        end run
        """
}
