import CueCore
import Foundation

/// What Cue's MCP server needs from the app: the deck the user is editing,
/// a way to change it (live, with undo and change sets), and the user's
/// answers. The app implements it over the front-most editor window; tests
/// implement it over a plain `DeckDocument`.
public protocol DeckHost: Sendable {
    /// The deck Claude works on, as it is now, or nil when none is open.
    func currentDocument() async -> DeckDocument?
    /// What the user has selected on the slide right now.
    func selection() async -> SelectionInfo?
    /// Applies the operations as one change set from `client`. Not saved.
    func apply(_ operations: [EditOperation], summary: String, client: String, slide: Int?) async throws -> ChangeSet
    func changes() async -> [ChangeSet]
    func accept(_ id: String) async throws
    func revert(_ id: String) async throws
    /// A PNG of the slide as rendered, at its final build unless `build` is given.
    func renderSlide(_ slide: Int, build: Int?) async throws -> Data
    /// Whether this client may use Cue's tools. Asking the user is the host's job.
    func approval(for client: String) async -> ClientApproval.Decision
    /// Ask-bar requests waiting for Claude.
    var mailbox: RequestMailbox { get }
    /// Downloads an image Claude asked Cue to add (`insert_image` with a url).
    func fetchImage(_ url: URL) async throws -> Data
    /// An approved tool call is starting (e.g. to animate the Ask bar while Claude edits).
    func toolDidStart(_ activity: ToolActivity) async
    /// It finished; `failed` when it returned an error.
    func toolDidFinish(_ activity: ToolActivity, failed: Bool) async
}

extension DeckHost {
    public func fetchImage(_ url: URL) async throws -> Data { try await ImageDownloader().fetch(url) }
    public func toolDidStart(_ activity: ToolActivity) async {}
    public func toolDidFinish(_ activity: ToolActivity, failed: Bool) async {}
}

/// The selection, as Claude sees it in `get_selection`.
public struct SelectionInfo: Sendable, Codable, Equatable {
    /// 1-based, like every slide number Claude sees.
    public var slide: Int
    public var cueID: String?
    /// Child-element indices from `<html>`; usable as a tool target.
    public var path: [Int]
    public var tag: String
    public var label: String?
    /// The element's start tag as written in the file.
    public var startTag: String?
    public var computedStyle: [String: String]

    public init(slide: Int, cueID: String?, path: [Int], tag: String, label: String?, startTag: String?,
                computedStyle: [String: String]) {
        self.slide = slide
        self.cueID = cueID
        self.path = path
        self.tag = tag
        self.label = label
        self.startTag = startTag
        self.computedStyle = computedStyle
    }
}

public enum CueMCPError: Error, LocalizedError, Equatable {
    case noDeck
    case notApproved(String)
    case denied(String)
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .noDeck: "No deck is open in Cue. Ask the user to open one."
        case .notApproved(let client):
            "Waiting for approval in Cue: the user needs to allow “\(client)” to edit decks. Try again in a moment."
        case .denied(let client): "The user doesn't allow “\(client)” to edit decks in Cue (Settings › Claude)."
        case .invalid(let message): message
        }
    }
}
