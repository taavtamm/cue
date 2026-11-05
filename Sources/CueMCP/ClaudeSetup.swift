import Foundation

/// Connecting Claude to Cue: the Claude Code command, the Claude Desktop
/// config entry, and the instruction that starts the Ask-bar loop.
public enum ClaudeSetup {
    public static let serverName = "cue"

    /// `claude mcp add cue -- "/Applications/Cue.app/Contents/MacOS/cue-mcp"`
    public static func claudeCodeCommand(helperPath: String) -> String {
        "claude mcp add \(serverName) -- \"\(helperPath)\""
    }

    /// The entry for Claude Desktop's `claude_desktop_config.json`.
    public static func desktopSnippet(helperPath: String) -> String {
        let entry: [String: Any] = ["mcpServers": [serverName: ["command": helperPath, "args": [String]()]]]
        let data = (try? JSONSerialization.data(withJSONObject: entry, options: [.prettyPrinted, .sortedKeys,
                                                                               .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    /// Paste into a Claude Code session to have it serve the Ask bar.
    public static let askLoopInstruction = """
        Use the Cue MCP tools to serve my Ask bar: call next_request in a loop. For each request, look at \
        get_outline and get_selection, make the change with Cue's tools (small edits, check with render_slide), \
        then call complete_request with a one-line summary. Keep listening until I say stop.
        """

    /// `~/Library/Application Support/Claude/claude_desktop_config.json`
    public static var desktopConfigURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Claude/claude_desktop_config.json")
    }

    /// The config with Cue's server added or updated. Every other key and
    /// server is kept. Refuses a file that isn't a JSON object rather than
    /// replacing it.
    public static func merged(_ existing: Data?, helperPath: String) throws -> Data {
        var config: [String: Any] = [:]
        if let existing, !existing.isEmpty {
            guard let object = try? JSONSerialization.jsonObject(with: existing) as? [String: Any] else {
                throw SetupError.unreadableConfig
            }
            config = object
        }
        var servers = config["mcpServers"] as? [String: Any] ?? [:]
        if config["mcpServers"] != nil, !(config["mcpServers"] is [String: Any]) { throw SetupError.unreadableConfig }
        servers[serverName] = ["command": helperPath, "args": [String]()]
        config["mcpServers"] = servers
        return try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys,
                                                                         .withoutEscapingSlashes])
    }

    /// Adds Cue to Claude Desktop's config, backing the old file up first.
    /// Returns the backup's URL, if there was a file to back up.
    @discardableResult
    public static func addToClaudeDesktop(helperPath: String, config url: URL = desktopConfigURL) throws -> URL? {
        let fileManager = FileManager.default
        let existing = fileManager.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        let updated = try merged(existing, helperPath: helperPath)
        var backup: URL?
        if let existing {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let copy = url.deletingLastPathComponent().appending(path: "claude_desktop_config.cue-backup-\(stamp).json")
            try existing.write(to: copy, options: .atomic)
            backup = copy
        } else {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        try updated.write(to: url, options: .atomic)
        return backup
    }

    public enum SetupError: Error, LocalizedError, Equatable {
        case unreadableConfig
        public var errorDescription: String? {
            "Claude Desktop's config file isn't valid JSON, so Cue left it alone. Add the snippet by hand."
        }
    }
}
