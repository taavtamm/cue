import CueCore
import Foundation

/// Plain-words explanations of why Cue refused an edit.
enum EditorMessages {
    // One plain case per error: long, but flat.
    // swiftlint:disable:next cyclomatic_complexity
    static func describe(_ error: any Error) -> String {
        guard let edit = error as? EditError else { return error.localizedDescription }
        switch edit {
        case .elementNotFound, .elementHasNoSource:
            return "This element was made by the deck's own script, so it has no HTML to edit."
        case .notALeaf:
            return "This element contains other elements. Select the text inside it to edit."
        case .rawTextElement(let tag):
            return "The contents of <\(tag)> are code, not text."
        case .voidElement(let tag):
            return "<\(tag)> can't contain text."
        case .slideOutOfRange(let index):
            return "There is no slide \(index + 1)."
        case .lastSlide:
            return "A deck needs at least one slide."
        case .unencodable(let character):
            return "The file's text encoding can't store “\(character)”."
        case .invalidAttributeName(let name):
            return "“\(name)” isn't a valid attribute name."
        case .invalidStyleProperty(let name):
            return "“\(name)” isn't a valid CSS property."
        case .unsupported(let what):
            return "Cue can't edit \(what) yet."
        case .patchOutOfRange, .malformedSource:
            return "Cue couldn't place this edit safely in the file, so it left the file alone."
        case .nothingToUndo:
            return "Nothing to undo."
        case .nothingToRedo:
            return "Nothing to redo."
        }
    }
}
