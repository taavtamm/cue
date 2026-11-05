import Intents
import Security

/// Tells the show whether Focus / Do Not Disturb is on, so Cue can warn the
/// presenter before notifications reach the projector. Cue never changes
/// Focus itself; macOS doesn't allow apps to.
///
/// Reading Focus needs the Communication Notifications entitlement and a
/// one-time user permission. Without either, the state is `.unknown` and
/// the show runs exactly as before.
///
/// Never ask for permission without the entitlement: on macOS 27 the
/// privacy system kills an app that requests Focus access without it.
@MainActor
final class FocusStatusMonitor {
    enum State: Equatable {
        case on, off, unknown
    }

    private let center = INFocusStatusCenter.default

    /// Asks for permission the first time; later calls return at once.
    func currentState() async -> State {
        guard Self.hasFocusEntitlement else { return .unknown }
        let status = await authorization()
        guard status == .authorized else { return .unknown }
        switch center.focusStatus.isFocused {
        case true?: return .on
        case false?: return .off
        case nil: return .unknown
        }
    }

    /// Whether this build is signed with the Communication Notifications
    /// entitlement (needs a provisioning profile; ad-hoc builds don't have it).
    static let hasFocusEntitlement: Bool = {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.usernotifications.communication" as CFString, nil)
        return (value as? Bool) == true
    }()

    private func authorization() async -> INFocusStatusAuthorizationStatus {
        if center.authorizationStatus != .notDetermined {
            return center.authorizationStatus
        }
        return await withCheckedContinuation { continuation in
            center.requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}
