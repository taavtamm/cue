import CueRender
import Foundation

/// The animation timeline under the slide: one row per animation, laid out
/// as fractions of a shared time span so the view only scales them.
public struct TimelineLayout: Sendable, Equatable {
    public struct Row: Sendable, Equatable, Identifiable {
        public let id: Int
        public let title: String
        /// Where the bar starts and how wide it is, 0…1 of `span`.
        public let start: Double
        public let width: Double
        public let loops: Bool
        /// A live web embed: it animates on its own, so it spans the whole row.
        public let isEmbed: Bool
    }

    public let rows: [Row]
    /// Seconds the ruler covers, at least `minimumSpan`.
    public let span: TimeInterval

    public static let minimumSpan: TimeInterval = 4

    public init(_ animations: SlideAnimations) {
        let ends = animations.tracks.map { $0.delay + $0.duration * ($0.loops ? 1 : max(1, $0.iterations)) }
        let span = max(Self.minimumSpan, (ends.max() ?? 0).rounded(.up))
        self.span = span
        var rows = animations.tracks.enumerated().map { index, track in
            let start = min(1, track.delay / span)
            let runs = track.duration * max(1, track.iterations)
            return Row(
                id: index, title: Self.title(track), start: start,
                width: track.loops ? 1 - start : min(1, runs / span), loops: track.loops, isEmbed: false
            )
        }
        if animations.embedCount > 0 {
            let count = animations.embedCount
            let title = count == 1 ? "Web embed · live loop" : "\(count) web embeds · live"
            rows.append(Row(id: rows.count, title: title, start: 0, width: 1, loops: true, isEmbed: true))
        }
        self.rows = rows
    }

    /// Whole seconds for the ruler: 0s, 1s, … span.
    public var ticks: [Int] { Array(0...Int(span)) }

    private static func title(_ track: SlideAnimations.Track) -> String {
        let name = track.name == "animation" ? "" : " · \(track.name)"
        return track.target.isEmpty ? track.name : track.target + name
    }
}
