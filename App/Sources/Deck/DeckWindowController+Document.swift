import AppKit
import CueEditor

/// Save, revert, undo and the unsaved-changes prompt.
extension DeckWindowController: NSMenuItemValidation {
    @objc func saveDocument(_ sender: Any?) {
        do {
            try session.save()
            window?.isDocumentEdited = false
        } catch {
            presentError(error)
        }
    }

    @objc func revertDocumentToSaved(_ sender: Any?) {
        guard let window, session.isDirty else { return }
        let alert = NSAlert()
        alert.messageText = "Revert to the saved version of “\(session.title)”?"
        alert.informativeText = "Your unsaved changes will be lost."
        alert.addButton(withTitle: "Revert")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            Task {
                try? await self.session.revert()
                await self.thumbnails.load(self.session.document)
                self.window?.isDocumentEdited = false
            }
        }
    }

    @objc func undoEdit(_ sender: Any?) { Task { await session.undo() } }
    @objc func redoEdit(_ sender: Any?) { Task { await session.redo() } }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(undoEdit(_:)): session.canUndo
        case #selector(redoEdit(_:)): session.canRedo
        case #selector(saveDocument(_:)), #selector(revertDocumentToSaved(_:)): session.isDirty
        default: true
        }
    }

    /// Unsaved edits the user hasn't chosen to discard.
    var needsSaving: Bool { session.isDirty && !discardsChanges }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard needsSaving else { return true }
        askToSave { saved in if saved { sender.close() } }
        return false
    }

    /// Asks Save / Don't Save / Cancel for this deck. Calls back with true
    /// when the window may go (saved or discarded), false when cancelled.
    func askToSave(_ done: @escaping (Bool) -> Void) {
        guard needsSaving, let window else { return done(true) }
        window.makeKeyAndOrderFront(nil)
        UnsavedChangesPrompt.ask(about: session.document, title: session.title, in: window) { [weak self] choice in
            guard let self else { return done(true) }
            switch choice {
            case .save:
                self.saveDocument(nil)
                done(!self.session.isDirty) // A failed save keeps the window open.
            case .discard:
                self.window?.isDocumentEdited = false
                self.discardsChanges = true
                done(true)
            case .cancel:
                done(false)
            }
        }
    }
}
