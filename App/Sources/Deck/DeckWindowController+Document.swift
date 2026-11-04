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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard session.isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to “\(session.title)”?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")
        alert.beginSheetModal(for: sender) { [weak self] response in
            guard let self else { return }
            switch response {
            case .alertFirstButtonReturn:
                self.saveDocument(nil)
                if !self.session.isDirty { sender.close() }
            case .alertThirdButtonReturn:
                self.window?.isDocumentEdited = false
                sender.close()
            default:
                break
            }
        }
        return false
    }
}
