import Foundation

extension DeckDocument {
    /// The file this deck was converted from (e.g. "Talk.pptx"), when Cue
    /// imported it. Cue saves edits to the HTML copy; the original is never
    /// changed.
    public var importedFrom: String? {
        tree.meta(named: "cue:imported-from").flatMap { $0.isEmpty ? nil : $0 }
    }
}
