import CueCore
import Foundation

/// What the sandbox noticed on a surface. Kept apart from `BridgeEvent`,
/// which is about showing slides, so presenting code can ignore it.
public enum SandboxEvent: Sendable, Equatable {
    /// Hosts the page tried to reach while it ran. All were blocked unless
    /// already allowed; the deck window may ask the user about them.
    case remoteResources([RemoteResource])
    /// The deck's scripts stopped responding, so Cue reloaded this surface
    /// with deck scripts turned off. Cue's own player keeps working.
    case scriptsStopped
    /// Something the sandbox refused, for diagnostics and tests.
    case refused(SandboxRefusal)
}

public enum SandboxRefusal: Sendable, Equatable {
    case navigation(url: String, mainFrame: Bool)
    case newWindow(url: String)
    case download(url: String)
    case permission(String)
}
