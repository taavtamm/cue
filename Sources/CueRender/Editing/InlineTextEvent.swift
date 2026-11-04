import CoreGraphics
import Foundation

/// What happens while the user edits text directly on the slide. Rects are
/// in the page's CSS pixels (origin top-left); `SlideRenderer.viewRect(fromCSS:)`
/// turns them into the surface's coordinates.
public enum InlineTextEvent: Sendable, Equatable, Codable {
    /// The insertion point moved. `collapsed` is false for a ranged selection,
    /// where Cue hides its caret.
    case caret(CGRect, collapsed: Bool)
    /// The user typed; the caret stays solid for a moment.
    case input(CGRect, collapsed: Bool)
    /// Return or click-away: the element's new plain text, and for a text
    /// box with formatting, its new markup (sanitised before it's written).
    case commit(cueID: String, text: String, html: String?)
    /// Escape: the page put the original content back.
    case cancel(cueID: String)

    init?(wire message: [String: Any]) {
        switch message["kind"] as? String {
        case "caret", "input":
            guard let rect = message["rect"] as? [String: Any] else { return nil }
            let frame = CGRect(
                x: rect["x"] as? Double ?? 0, y: rect["y"] as? Double ?? 0,
                width: rect["width"] as? Double ?? 0, height: rect["height"] as? Double ?? 0
            )
            let collapsed = rect["collapsed"] as? Bool ?? true
            let typed = message["kind"] as? String == "input"
            self = typed ? .input(frame, collapsed: collapsed) : .caret(frame, collapsed: collapsed)
        case "commit":
            guard let id = message["cueID"] as? String else { return nil }
            self = .commit(cueID: id, text: message["text"] as? String ?? "", html: message["html"] as? String)
        case "cancel":
            self = .cancel(cueID: message["cueID"] as? String ?? "")
        default:
            return nil
        }
    }
}
