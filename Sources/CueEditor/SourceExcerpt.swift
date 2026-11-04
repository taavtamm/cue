import CueCore
import Foundation

/// The text the HTML view shows: the current slide's markup with long
/// data: URLs shortened, and where the selected element starts in it.
public struct SourceExcerpt: Sendable {
    public let title: String
    public let text: String
    /// The selected element's start tag, in `text`.
    public let highlight: NSRange?

    /// Data URLs longer than this are shown as `data:image/png;base64,… (84 KB)`.
    static let longDataURL = 160

    @MainActor public init(session: EditorSession) {
        let source = session.document.source as NSString
        let slide = session.currentSlide
        let range = slide?.sourceRange ?? SourceRange(start: 0, end: source.length)
        let clamped = NSRange(location: range.start, length: min(range.length, source.length - range.start))
        let raw = source.substring(with: clamped)
        title = "Slide \(session.slide + 1) · \(slide?.label ?? "")"
        text = Self.shortened(raw)
        if let element = session.selection?.element, let start = element.startTag, start.start >= range.start {
            let prefix = NSRange(location: range.start, length: start.start - range.start)
            let before = Self.shortened(source.substring(with: prefix))
            highlight = NSRange(location: (before as NSString).length, length: start.length)
        } else {
            highlight = nil
        }
    }

    static func shortened(_ html: String) -> String {
        let pattern = "data:([a-z0-9.+/-]+);base64,([A-Za-z0-9+/=]{\(longDataURL),})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return html }
        let text = html as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: html, range: NSRange(location: 0, length: text.length)) {
            result += text.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let type = text.substring(with: match.range(at: 1))
            let kilobytes = max(1, match.range(at: 2).length * 3 / 4 / 1024)
            result += "data:\(type);base64,… (\(kilobytes) KB)"
            cursor = NSMaxRange(match.range)
        }
        return result + text.substring(from: cursor)
    }
}
