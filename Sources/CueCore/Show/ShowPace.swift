import Foundation

/// Whether the presenter is ahead of or behind a target duration, judged by
/// how far through the deck they are against how much time has passed.
public struct ShowPace: Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        case onPace
        /// Seconds behind the even-pace schedule.
        case behind(TimeInterval)
        /// Seconds ahead of it.
        case ahead(TimeInterval)
        /// Past the target duration.
        case overtime(TimeInterval)
    }

    /// Within this many seconds of schedule counts as on pace.
    public static let tolerance: TimeInterval = 45

    public let status: Status
    /// Elapsed as a fraction of the target, 0…1+.
    public let timeFraction: Double

    /// - Parameters:
    ///   - progress: how much of the deck is done, 0…1 (see `progress(of:in:)`).
    public init(elapsed: TimeInterval, target: TimeInterval, progress: Double) {
        let target = max(target, 1)
        timeFraction = elapsed / target
        if elapsed > target {
            status = .overtime(elapsed - target)
            return
        }
        let scheduled = progress * target
        let drift = elapsed - scheduled
        if abs(drift) <= Self.tolerance {
            status = .onPace
        } else {
            status = drift > 0 ? .behind(drift) : .ahead(-drift)
        }
    }

    /// Short text for the timer: "on pace", "2 min behind", "1 min ahead", "3 min over".
    public var text: String {
        switch status {
        case .onPace: "on pace"
        case .behind(let seconds): "\(Self.minutes(seconds)) min behind"
        case .ahead(let seconds): "\(Self.minutes(seconds)) min ahead"
        case .overtime(let seconds): "\(Self.minutes(seconds)) min over"
        }
    }

    private static func minutes(_ seconds: TimeInterval) -> Int { max(1, Int((seconds / 60).rounded())) }

    /// Fraction of the deck finished: slides before this one, plus the share
    /// of this slide's builds already shown.
    public static func progress(of position: ShowPosition, stateCounts: [Int]) -> Double {
        guard !stateCounts.isEmpty else { return 0 }
        let slide = min(max(0, position.slide), stateCounts.count - 1)
        let states = Double(max(1, stateCounts[slide]))
        let withinSlide = Double(position.build) / states
        return (Double(slide) + withinSlide) / Double(stateCounts.count)
    }

    /// A target when the deck doesn't set one: rehearsed time if there is
    /// any, else `minutesPerSlide` a slide (Settings, two by default)
    /// rounded up to five minutes.
    public static func defaultTarget(
        slideCount: Int, rehearsed: [Double] = [], minutesPerSlide: Double = 2
    ) -> TimeInterval {
        let total = rehearsed.reduce(0, +)
        if total > 0 { return total }
        let minutes = max(5, Int((Double(slideCount) * minutesPerSlide / 5).rounded(.up)) * 5)
        return TimeInterval(minutes * 60)
    }
}
