import Foundation

/// How open slide surfaces catch up with an edit without a reload where
/// possible. Elements are named by `cueID`, as tagged in the live DOM.
public enum LiveUpdate: Sendable, Equatable {
    /// Apply these DOM changes. `remap` means elements were added or removed,
    /// so the live `data-cue-id`s must be re-assigned from the new manifest.
    case inPlace([DOMChange], remap: Bool)
    /// Structure changed (slides, builds): reload, keeping the show position.
    case reload
    case none
}

public enum DOMChange: Sendable, Equatable, Codable {
    /// Re-parses a leaf element's content exactly as the browser would read the source.
    case setInnerHTML(cueID: String, html: String)
    case setAttribute(cueID: String, name: String, value: String?)
    /// The full CSS of Cue's override block. Created at the end of `<head>` if missing.
    case setOverrides(css: String)
    /// New markup at the end of an element, exactly as the source now has it.
    case insertHTML(parentCueID: String, html: String)
    case remove(cueID: String)
}

/// What the editor decided while making the patch; turned into a
/// `LiveUpdate` once the new source has been parsed.
enum LivePlan: Sendable, Equatable {
    case innerHTML(ElementPath)
    case attribute(ElementPath, name: String)
    case overrides(created: Bool)
    /// Markup appended inside this element (the new element is its last child).
    case inserted(parent: ElementPath)
    /// An element removed; named by its live id from before the edit.
    case removed(cueID: String)
    case reload
}
