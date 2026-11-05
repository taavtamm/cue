import Foundation

/// Something the user typed into Cue's Ask bar, waiting for Claude.
/// Milestone 7 serves these to a connected Claude Code session over MCP
/// (`next_request`); until then they only queue.
public struct AskRequest: Sendable, Equatable, Codable, Identifiable {
    public enum Status: String, Sendable, Codable {
        /// Waiting for a connected Claude session to pick it up.
        case waiting
        /// A session has it and is working.
        case inProgress
        case done
        case cancelled
    }

    public let id: UUID
    public let text: String
    /// The slide the user was looking at, 0-based.
    public let slide: Int
    /// The selected element's path from `<html>`, if something was selected.
    public let selection: ElementPath?
    public let createdAt: Date
    public internal(set) var status: Status
    /// What Claude said it did, once done.
    public internal(set) var summary: String?

    public init(text: String, slide: Int, selection: ElementPath?, createdAt: Date = Date()) {
        id = UUID()
        self.text = text
        self.slide = slide
        self.selection = selection
        self.createdAt = createdAt
        status = .waiting
    }
}
