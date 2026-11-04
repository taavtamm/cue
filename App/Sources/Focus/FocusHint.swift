import CueUI
import Foundation

/// Whether to warn that Focus is off, and the warning's text. The Focus state
/// is injected, so the hint can be shown and tested without the entitlement.
@MainActor
enum FocusHint {
    typealias StateProvider = @MainActor () async -> FocusStatusMonitor.State

    static let message = "Focus is off — notifications may appear on stage."
    static let detail = "Turn on Do Not Disturb in Control Center."

    /// The shared non-modal banner, with a Dismiss button.
    static func banner(onDismiss: @escaping () -> Void) -> Banner {
        Banner(systemImage: "moon", message: message, detail: detail, actions: [.init("Dismiss", run: onDismiss)])
    }

    /// Only a known "off" warrants a warning; unknown shows nothing.
    static func shouldWarn(_ state: FocusStatusMonitor.State) -> Bool { state == .off }

    /// The real Focus state, or in Debug builds `-focusState on|off|unknown`.
    static let systemState: StateProvider = {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "focusState") {
        case "on": return .on
        case "off": return .off
        case "unknown": return .unknown
        default: break
        }
        #endif
        return await FocusStatusMonitor().currentState()
    }
}
