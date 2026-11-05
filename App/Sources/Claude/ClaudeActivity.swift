import Foundation
import Observation

/// What the connected agent is doing, from the tools it calls: reading,
/// looking at a slide, editing, or listening for Ask-bar requests. The Ask
/// bar shows it. Edits take milliseconds, so a finished one stays on show
/// for a moment; otherwise "Editing…" would never be seen.
@MainActor @Observable
final class ClaudeActivity {
    enum Kind: Sendable, Equatable { case reading, rendering, editing, waiting }

    struct Entry: Identifiable, Equatable {
        let id: UUID
        let client: String
        let tool: String
        let kind: Kind
        /// 1-based.
        let slide: Int?
        let detail: String?
    }

    /// How long a finished call stays on show.
    static let linger: Duration = .milliseconds(1_400)

    private(set) var running: [Entry] = []
    /// The last finished call, while it lingers.
    private(set) var lingering: Entry?
    /// Clients with a next_request open: they'll take an Ask-bar request at once.
    var listeningClients: Set<String> { Set(running.filter { $0.kind == .waiting }.map(\.client)) }

    func started(_ entry: Entry) {
        running.append(entry)
    }

    func finished(_ id: UUID) {
        guard let index = running.firstIndex(where: { $0.id == id }) else { return }
        let entry = running.remove(at: index)
        guard entry.kind != .waiting else { return }
        lingering = entry
        Task { [weak self] in
            try? await Task.sleep(for: Self.linger)
            if self?.lingering?.id == entry.id { self?.lingering = nil }
        }
    }

    /// The call to show: an edit first, then anything else running, then the one just done.
    var shown: Entry? {
        running.last { $0.kind == .editing } ?? running.last { $0.kind != .waiting } ?? lingering
    }

    /// "Editing slide 1 · Slide 1 title…", "Looking at slide 3…", "Reading the deck…".
    static func describe(_ entry: Entry) -> String {
        let slide = entry.slide.map { "slide \($0)" }
        switch entry.kind {
        case .editing:
            let what = [slide.map { "Editing \($0)" } ?? "Editing the deck", entry.detail].compactMap { $0 }
            return what.joined(separator: " · ") + "…"
        case .rendering:
            return entry.tool == "render_deck" ? "Looking at all the slides…" : "Looking at \(slide ?? "the slide")…"
        case .reading:
            switch entry.tool {
            case "get_selection": return "Looking at what you've selected…"
            case "get_styles": return "Reading the deck's styles…"
            default: return slide.map { "Reading \($0)…" } ?? "Reading the deck…"
            }
        case .waiting:
            return "Listening"
        }
    }
}
