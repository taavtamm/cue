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

    /// `source` is the text the edit was applied to; when given, each excerpt
    /// is widened to the surrounding text (up to the nearest tag), so the user
    /// sees "hold up." → "hold up everywhere.", not "" → "everyw".
    public init(id: String, client: String, summary: String, slide: Int?, applied: SourceEdit, inverse: SourceEdit,
                source: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.client = client
        self.summary = summary
        self.slide = slide
        self.createdAt = createdAt
        status = .pending
        self.inverse = inverse
        excerpts = zip(applied.patches, inverse.patches).map { forward, back in
            guard let source else { return Excerpt(before: Self.clip(back.replacement), after: Self.clip(forward.replacement)) }
            return Self.excerpt(of: forward, in: source)
        }
    }

    /// The changed region with its surrounding text, stopping at a tag edge
    /// (`>` before it, `<` after it) or after `reach` characters.
    static func excerpt(of patch: SourcePatch, in source: String, reach: Int = 80) -> Excerpt {
        let text = Array(source.utf16)
        var start = min(patch.range.start, text.count), end = min(patch.range.end, text.count)
        let open = UInt16(UInt8(ascii: "<")), close = UInt16(UInt8(ascii: ">"))
        var steps = 0
        while start > 0, text[start - 1] != close, steps < reach { start -= 1; steps += 1 }
        steps = 0
        while end < text.count, text[end] != open, steps < reach { end += 1; steps += 1 }
        let lead = String(decoding: text[start..<patch.range.start], as: UTF16.self)
        let old = String(decoding: text[patch.range.start..<patch.range.end], as: UTF16.self)
        let tail = String(decoding: text[patch.range.end..<end], as: UTF16.self)
        return Excerpt(before: clip(lead + old + tail), after: clip(lead + patch.replacement + tail))
    }

    static func clip(_ text: String, limit: Int = 400) -> String {
        text.count <= limit ? text : String(text.prefix(limit)) + "…"
    }
}
