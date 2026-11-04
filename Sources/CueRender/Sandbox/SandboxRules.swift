import CueCore
import Foundation

/// The per-deck facts the navigation and permission checks need.
struct SandboxRules: Sendable {
    /// The one document the top frame may show.
    var pageURL: URL
    /// Hosts the user allowed; frames from them may load too.
    var allowedHosts: [String]
    var permissions: DeckPermissions

    /// Top frame: only the deck's own page (reloads and #fragments included).
    func allowsMainFrame(_ url: URL) -> Bool {
        url.scheme?.lowercased() == pageURL.scheme && url.host == pageURL.host && url.path == pageURL.path
    }

    /// Frames inside the page: inline (srcdoc, about:blank), the deck folder,
    /// or an allowed host. No data: or blob: documents, no file:.
    func allowsSubframe(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "about": return true
        case DeckSchemeHandler.scheme: return url.host == DeckSchemeHandler.host
        case "https": return allowedHosts.contains { NetworkRules.matches(url, allowed: $0) }
        default: return false
        }
    }
}
