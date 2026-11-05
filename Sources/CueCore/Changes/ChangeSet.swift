import Foundation

/// One edit Claude (or another client) made through Cue's MCP server. It is
/// applied straight away, so the slide shows it, and stays pending until the
/// user accepts it or undoes it.
public struct ChangeSet: Sendable, Equatable, Codable, Identifiable {
    public enum Status: String, Sendable, Codable {
        /// Applied, waiting for Accept or Undo.
        case pending
        /// Kept.
        case accepted
        /// Undone.
        case reverted
        /// Later edits touched the same text, so it can't be undone on its own any more.
        case superseded
    }

    /// One changed region, for a compact diff: what was there, what is there now.
    public struct Excerpt: Sendable, Equatable, Codable {
        public let before: String
        public let after: String
    }

    public let id: String
    /// The MCP client, e.g. "claude-code".
    public let client: String
    public let summary: String
    /// 0-based slide the change is on, when known.
    public let slide: Int?
    public let createdAt: Date
    public internal(set) var status: Status
    public let excerpts: [Excerpt]
    /// The patches that undo this change, in the *current* source's offsets.
    public internal(set) var inverse: SourceEdit

    public init(id: String, client: String, summary: String, slide: Int?, applied: SourceEdit, inverse: SourceEdit,
                createdAt: Date = Date()) {
        self.id = id
        self.client = client
        self.summary = summary
        self.slide = slide
        self.createdAt = createdAt
        status = .pending
        self.inverse = inverse
        excerpts = zip(applied.patches, inverse.patches).map { forward, back in
            Excerpt(before: Self.clip(back.replacement), after: Self.clip(forward.replacement))
        }
    }

    static func clip(_ text: String, limit: Int = 400) -> String {
        text.count <= limit ? text : String(text.prefix(limit)) + "…"
    }
}
