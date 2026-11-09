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
    /// The same, refused when the deck is no longer `source`: the operations
    /// were planned on it (element paths, slide numbers), and a change by the
    /// user, another call or a different deck window would make them land wrong.
    func apply(_ operations: [EditOperation], summary: String, client: String, slide: Int?,
               plannedOn source: String) async throws -> ChangeSet
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

    // Decks: Claude can make, open, switch between and save presentations.
    /// Open decks first (the target marked), then recently opened ones.
    func decks() async -> [DeckSummary]
    /// Writes a new deck (`html`, or Cue's blank deck) at `url`, opens it and makes it the target.
    func createDeck(at url: URL, title: String, html: String?) async throws -> DeckSummary
    /// Opens a deck (HTML, or a presentation Cue imports) and makes it the target.
    func openDeck(_ url: URL) async throws -> DeckSummary
    /// Saves the target deck to its own file.
    func saveDeck() async throws -> DeckSummary
    /// Where new decks go when Claude doesn't say.
    func newDeckFolder() async -> URL
    /// New decks must be inside this folder (the user's home folder).
    func deckRoot() async -> URL
}

extension DeckHost {
    public func fetchImage(_ url: URL) async throws -> Data { try await ImageDownloader().fetch(url) }
    public func toolDidStart(_ activity: ToolActivity) async {}
    public func toolDidFinish(_ activity: ToolActivity, failed: Bool) async {}
    public func decks() async -> [DeckSummary] { [] }
    public func createDeck(at url: URL, title: String, html: String?) async throws -> DeckSummary {
        throw CueMCPError.invalid("This Cue can't create decks.")
    }
    public func openDeck(_ url: URL) async throws -> DeckSummary { throw CueMCPError.invalid("This Cue can't open decks.") }
    public func saveDeck() async throws -> DeckSummary { throw CueMCPError.invalid("This Cue can't save decks.") }
    public func newDeckFolder() async -> URL { NewDeckLocation.defaultFolder(saveFolder: nil) }
    public func deckRoot() async -> URL { FileManager.default.homeDirectoryForCurrentUser }
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

public extension DeckHost {
    func apply(_ operations: [EditOperation], summary: String, client: String, slide: Int?,
               plannedOn source: String) async throws -> ChangeSet {
        guard await currentDocument()?.source == source else { throw CueMCPError.deckChanged }
        return try await apply(operations, summary: summary, client: client, slide: slide)
    }
}
