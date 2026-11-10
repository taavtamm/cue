import AppKit
import CueCore

/// Whether the editor's live slide should play. It pauses when nobody can
/// see it (covered, minimised), when the user paused it, and, with the
/// setting on, while another app is active, unless Claude worked on the deck
/// in the last half minute, so its edits still show live.
@MainActor
final class LivePlaybackPolicy {
    /// How long after Claude's last call a background window keeps playing.
    static let claudeGrace: TimeInterval = 30

    private let apply: (_ paused: Bool) -> Void
    private var observers: [NSObjectProtocol] = []
    private var recheck: Task<Void, Never>?
    var isVisible = true { didSet { update() } }
    var isPlayingLive = true { didSet { update() } }
    var isShowing = false { didSet { update() } }

    init(apply: @escaping (_ paused: Bool) -> Void) {
        self.apply = apply
        let center = NotificationCenter.default
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            })
        }
    }

    isolated deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        recheck?.cancel()
    }

    /// Re-evaluates now; called on every input change and by Claude's activity.
    func update() {
        guard !isShowing else { return } // A running show owns the canvas.
        let background = CueSettings.shared.pausesLiveContentInBackground && !NSApp.isActive
        let claudeWorking = ClaudeConnection.shared.activity.lastWorked
            .map { Date().timeIntervalSince($0) < Self.claudeGrace } ?? false
        apply(!isVisible || !isPlayingLive || (background && !claudeWorking))
        scheduleRecheck(background: background, claudeWorking: claudeWorking)
    }

    /// In the background, look again when Claude's grace period runs out.
    private func scheduleRecheck(background: Bool, claudeWorking: Bool) {
        recheck?.cancel()
        guard background, claudeWorking, let last = ClaudeConnection.shared.activity.lastWorked else { return }
        let wait = max(1, Self.claudeGrace - Date().timeIntervalSince(last) + 0.5)
        recheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            self?.update()
        }
    }
}
