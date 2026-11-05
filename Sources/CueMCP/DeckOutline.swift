import CueCore
import Foundation

/// `get_outline` and `cue://deck/outline`: the deck at a glance.
struct DeckOutline: Encodable {
    struct Slide: Encodable {
        let number: Int
        let id: String
        let label: String
        let notes: String
        let builds: Int
        let hasLiveContent: Bool
    }

    let file: String
    let importedFrom: String?
    let canvas: String
    let format: String
    let slides: [Slide]

    init(_ document: DeckDocument) {
        let structure = document.structure
        file = document.fileURL.lastPathComponent
        importedFrom = document.importedFrom
        canvas = "\(Int(structure.canvas.width))×\(Int(structure.canvas.height))"
        format = structure.adapter.rawValue
        slides = structure.slides.enumerated().map { index, slide in
            Slide(number: index + 1, id: slide.id, label: slide.label, notes: slide.notes,
                  builds: slide.builds.count, hasLiveContent: slide.hasLiveContent)
        }
    }

    /// A range of the source, with large embedded images as placeholders
    /// (see `ImagePlaceholders`), cut at `limit` characters with a note.
    static func slice(_ source: String, _ range: SourceRange, limit: Int) -> String {
        let raw = (source as NSString).substring(with: NSRange(location: range.start, length: range.length))
        let text = ImagePlaceholders.shorten(raw)
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "\n<!-- … cut at \(limit) characters; the slide is longer. -->"
    }
}

/// A change set as Claude sees it.
struct ChangeSetReport: Encodable {
    let id: String
    let status: String
    let summary: String
    let slide: Int?
    let changes: [ChangeSet.Excerpt]
    let note: String

    init(_ change: ChangeSet) {
        id = change.id
        status = change.status.rawValue
        summary = change.summary
        slide = change.slide.map { $0 + 1 }
        changes = change.excerpts
        note = change.status == .pending
            ? "Applied live in Cue, not saved. The user accepts or undoes it."
            : "The user has \(change.status.rawValue) this change."
    }
}
