import AppKit

/// Hides the pointer after it has been still for a while during the show.
/// AppKit shows it again by itself on the next movement.
@MainActor
final class CursorHider {
    private let delay: Duration
    private var pending: Task<Void, Never>?

    init(delay: Duration = .seconds(2)) {
        self.delay = delay
    }

    func start() { noteMovement() }

    func noteMovement() {
        pending?.cancel()
        pending = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    func stop() {
        pending?.cancel()
        pending = nil
        NSCursor.setHiddenUntilMouseMoves(false)
    }
}
