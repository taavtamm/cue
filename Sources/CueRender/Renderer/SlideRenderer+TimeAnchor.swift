import Foundation

extension SlideRenderer {
    /// This surface's slide animations right now, for lining others up.
    public func readAnimationClock() async -> AnimationClock? {
        guard isReady,
              let value = try? await evaluateInBridge("return window.__cue.timeAnchor.read()"),
              let object = value as? [String: Any],
              let wall = object["wall"] as? Double
        else { return nil }
        let times = (object["times"] as? [Any] ?? []).map { $0 as? Double }
        return AnimationClock(wall: wall, times: times)
    }

    /// Sets this surface's slide animations to another surface's clock.
    public func alignAnimations(to clock: AnimationClock) {
        guard isReady else { return }
        send(.alignAnimations(clock))
    }
}
