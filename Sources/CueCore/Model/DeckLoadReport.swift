import Foundation

/// The heavy slides of a deck, worded for the warning banner and for the
/// prompt the user hands their AI to make the deck lighter.
public struct DeckLoadReport: Sendable, Equatable {
    /// Heavy slides, 0-based, in order.
    public let heavy: [(slide: Int, load: SlideLoad)]

    public init(_ loads: [Int: SlideLoad]) {
        heavy = loads.filter { $0.value.isHeavy }.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    public var isHeavy: Bool { !heavy.isEmpty }

    /// One sentence for the banner, naming the heaviest slide.
    public var message: String {
        guard let worst = heavy.max(by: { $0.load.reasons.count < $1.load.reasons.count }) else { return "" }
        let others = heavy.count - 1
        let more = others > 0 ? " (and \(others) more slide\(others == 1 ? "" : "s"))" : ""
        return "This deck keeps your GPU busy: slide \(worst.slide + 1) has \(Self.list(worst.load.reasons))\(more)."
    }

    /// The prompt to paste into Claude Code or Claude Desktop.
    public func prompt(deckTitle: String) -> String {
        let lines = heavy.map { "- Slide \($0.slide + 1): \(Self.list($0.load.reasons))" }.joined(separator: "\n")
        return """
            Using Cue, make the deck “\(deckTitle)” lighter on the GPU without changing how it looks. \
            Cue measured these slides while they played:
            \(lines)

            Call get_performance for the numbers on every slide. Ways to lighten it: replace backdrop-filter \
            blurs over moving content with solid or pre-blurred backgrounds; let looping animations finish, \
            or run them only on the slide that's showing; have embeds and scripts draw less often (honour \
            prefers-reduced-motion, stop when hidden). Check each slide you change with render_slide, then \
            call get_performance again to confirm it's lighter.
            """
    }

    /// "a, b and c".
    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    public static func == (lhs: DeckLoadReport, rhs: DeckLoadReport) -> Bool {
        lhs.heavy.map(\.slide) == rhs.heavy.map(\.slide) && lhs.heavy.map(\.load) == rhs.heavy.map(\.load)
    }
}
