import Foundation

/// A moment on one surface: the wall-clock time it was read, and the current
/// time of each running animation on the shown slide, in document order.
/// Applied to another surface it sets the same current times, advanced by
/// however long the message took, so both screens show the same frame.
public struct AnimationClock: Sendable, Equatable, Codable {
    /// Milliseconds since 1970, read with `Date.now()` in the page.
    public var wall: Double
    /// `Animation.currentTime` in ms; nil for animations that hadn't started.
    public var times: [Double?]

    public init(wall: Double, times: [Double?]) {
        self.wall = wall
        self.times = times
    }
}
