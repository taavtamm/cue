import Foundation
import MCP

/// What a connected Claude is doing right now, so Cue can show it (the Ask
/// bar animates while Claude edits). Reported around every approved tool call.
public struct ToolActivity: Sendable, Equatable {
    public enum Kind: Sendable {
        case reading, rendering, editing, waiting
    }

    public let id: UUID
    public let client: String
    public let tool: String
    public let kind: Kind
    /// 1-based, from the call's arguments, when it names a slide.
    public let slide: Int?
    /// The call's summary, or its target's selector, when it has one.
    public let detail: String?

    public init(id: UUID = UUID(), client: String, tool: String, kind: Kind, slide: Int?, detail: String?) {
        self.id = id
        self.client = client
        self.tool = tool
        self.kind = kind
        self.slide = slide
        self.detail = detail
    }

    /// Every tool, by what it does to the deck.
    public static func kind(forTool tool: String) -> Kind {
        switch tool {
        case "render_slide", "render_deck": .rendering
        case "next_request": .waiting
        case "complete_request", "list_changes": .reading
        default: tool.hasPrefix("get_") ? .reading : .editing
        }
    }

    init(client: String, tool: String, arguments: [String: Value]?) {
        let args = ToolArguments(arguments)
        let target = args.object("target")
        self.init(client: client, tool: tool, kind: Self.kind(forTool: tool),
                  slide: args.int("slide") ?? target?.int("slide"),
                  detail: args.string("summary") ?? target?.string("selector"))
    }
}
