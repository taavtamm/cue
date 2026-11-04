import CueCore
import CueRender
import Foundation

/// Every change to the deck: edits, undo, redo, save and revert. Edits run
/// one at a time, off the main thread (re-parsing a big deck takes a moment),
/// and the canvas catches up in place or by reloading.
extension EditorSession {
    @discardableResult
    public func apply(_ operation: EditOperation) async -> Bool {
        await serialized { document in try document.apply(operation) }
    }

    @discardableResult
    public func undo() async -> Bool {
        await serialized { document in try document.undo() }
    }

    @discardableResult
    public func redo() async -> Bool {
        await serialized { document in try document.redo() }
    }

    /// Writes the deck. Unchanged decks go back out byte for byte.
    public func save() throws {
        try document.save()
        document.markSaved()
    }

    /// Throws away unsaved edits and reloads the file from disk.
    public func revert() async throws {
        let url = document.fileURL
        document = try await Task.detached { try DeckDocument(contentsOf: url) }.value
        lastEditedAt = nil
        slide = min(slide, max(0, slideCount - 1))
        selection = nil
        try await loadCanvas()
        onDocumentChanged?(.none)
    }

    // MARK: Shortcuts for the inspector

    public func setStyle(_ field: StyleInput.Field, to input: String) async {
        guard let selection else { return }
        guard let value = StyleInput.cssValue(input, for: field) else {
            lastError = "“\(input)” isn't a value Cue can use here."
            return
        }
        await apply(.setStyle(selection.path, property: StyleInput.property(for: field), value: value))
    }

    /// Notes typed in the inspector: written after a short pause, and merged
    /// into one undo step by the history's coalescing.
    public func setNotesWhileTyping(_ text: String, slide index: Int, delay: Duration = .milliseconds(350)) {
        notesDebounce[index]?.cancel()
        notesDebounce[index] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            if self.structure.slides.indices.contains(index), self.structure.slides[index].notes != text {
                await self.apply(.setNotes(slide: index, text: text))
            }
        }
    }

    // MARK: Plumbing

    private func serialized(_ change: @escaping @Sendable (inout DeckDocument) throws -> EditResult) async -> Bool {
        let previous = editChain
        let task = Task<Bool, Never> { @MainActor in
            _ = await previous?.value
            return await self.perform(change)
        }
        editChain = task
        return await task.value
    }

    private func perform(_ change: @escaping @Sendable (inout DeckDocument) throws -> EditResult) async -> Bool {
        let current = document
        do {
            let (next, result) = try await Task.detached {
                var copy = current
                let result = try change(&copy)
                return (copy, result)
            }.value
            document = next
            lastEditedAt = Date()
            lastError = nil
            await catchUp(with: result)
            return true
        } catch {
            lastError = EditorMessages.describe(error)
            return false
        }
    }

    private func catchUp(with result: EditResult) async {
        liveSlides = liveSlides.filter { $0 < slideCount }
        if slide >= slideCount { slide = max(0, slideCount - 1) }
        do {
            try await canvas.applyLive(result.live, from: document)
        } catch {
            lastError = "The slide couldn't update live: \(error.localizedDescription)"
        }
        if result.live == .reload { canvas.show(ShowPosition(slide: slide), finished: true) }
        await refreshSelection()
        onDocumentChanged?(result)
    }
}
