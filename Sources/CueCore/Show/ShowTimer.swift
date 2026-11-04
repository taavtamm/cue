import Foundation

/// Elapsed presenting time that can pause. A value type driven by an
/// injected clock, so tests control time.
public struct ShowTimer: Sendable, Equatable {
    private var startedAt: TimeInterval?
    private var accumulated: TimeInterval = 0

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public mutating func start(at now: TimeInterval) {
        if startedAt == nil { startedAt = now }
    }

    public mutating func pause(at now: TimeInterval) {
        guard let startedAt else { return }
        accumulated += now - startedAt
        self.startedAt = nil
    }

    public mutating func reset() {
        startedAt = nil
        accumulated = 0
    }

    public func elapsed(at now: TimeInterval) -> TimeInterval {
        accumulated + (startedAt.map { now - $0 } ?? 0)
    }
}

/// A monotonic time source in seconds. `system` survives wall-clock changes.
public struct ShowClock: Sendable {
    public let now: @Sendable () -> TimeInterval
    public init(now: @escaping @Sendable () -> TimeInterval) {
        self.now = now
    }
    public static let system = ShowClock { ProcessInfo.processInfo.systemUptime }
}
