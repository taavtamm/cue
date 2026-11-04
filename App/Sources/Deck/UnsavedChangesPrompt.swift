import AppKit
import CueCore

/// The "save or discard?" questions, in one place: closing a deck window,
/// and quitting with unsaved decks. For an imported deck it says where the
/// changes go, because the original PowerPoint/Keynote/PDF is never changed.
@MainActor
enum UnsavedChangesPrompt {
    enum Choice { case save, discard, cancel }

    /// "Save changes to “Talk”?" with Save / Cancel / Don't Save.
    static func ask(about document: DeckDocument, title: String, in window: NSWindow,
                    _ answer: @escaping (Choice) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(title)”?"
        alert.informativeText = detail(for: document)
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")
        alert.buttons[2].hasDestructiveAction = true
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn: answer(.save)
            case .alertThirdButtonReturn: answer(.discard)
            default: answer(.cancel)
            }
        }
    }

    /// Quitting with several unsaved decks: review each, discard all, or stay.
    enum QuitChoice { case review, discardAll, cancel }

    static func askBeforeQuitting(count: Int) -> QuitChoice {
        let alert = NSAlert()
        alert.messageText = "You have \(count) presentations with unsaved changes. Review them before quitting?"
        alert.informativeText = "If you don't review them, all your changes will be lost."
        alert.addButton(withTitle: "Review Changes…")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard Changes and Quit")
        alert.buttons[2].hasDestructiveAction = true
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .review
        case .alertThirdButtonReturn: return .discardAll
        default: return .cancel
        }
    }

    static func detail(for document: DeckDocument) -> String {
        guard let original = document.importedFrom else {
            return "Your changes will be lost if you don't save them."
        }
        return "Cue saves them in “\(document.fileURL.lastPathComponent)”, next to the original. "
            + "“\(original)” itself isn't changed. Your changes will be lost if you don't save them."
    }
}
