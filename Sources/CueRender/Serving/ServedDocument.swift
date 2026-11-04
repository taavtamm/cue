import CueCore
import Foundation

/// The deck's main HTML as WebKit receives it. The file on disk is never
/// changed; only this in-memory copy differs, and only by dropping the
/// deck's own player script when Cue's universal player replaces it.
enum ServedDocument {
    static let replacementMarker = "<!-- Cue: the deck's player script is replaced by Cue's universal player -->"

    static func html(source: String, structure: DeckStructure) -> String {
        guard let range = structure.replacedPlayerScript else { return source }
        let text = source as NSString
        guard range.start >= 0, range.end <= text.length, range.start < range.end else { return source }
        let nsRange = NSRange(location: range.start, length: range.length)
        return text.replacingCharacters(in: nsRange, with: replacementMarker)
    }
}
