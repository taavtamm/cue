import Intents

/// Tells the show whether Focus / Do Not Disturb is on, so Cue can warn the
/// presenter before notifications reach the projector. Cue never changes
/// Focus itself; macOS doesn't allow apps to.
///
/// Reading Focus needs the Communication Notifications entitlement and a
/// one-time user permission. Without either, the state is `.unknown` and
/// the show runs exactly as before.
@MainActor
final class FocusStatusMonitor {
    enum State: Equatable {
        case on, off, unknown
    }

    private let center = INFocusStatusCenter.default

    /// Asks for permission the first time; later calls return at once.
    func currentState() async -> State {
        let status = await authorization()
        guard status == .authorized else { return .unknown }
        switch center.focusStatus.isFocused {
        case true?: return .on
        case false?: return .off
        case nil: return .unknown
        }
    }

    private func authorization() async -> INFocusStatusAuthorizationStatus {
        if center.authorizationStatus != .notDetermined {
            return center.authorizationStatus
        }
        return await withCheckedContinuation { continuation in
            center.requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}
