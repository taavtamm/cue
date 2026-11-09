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

    /// Undoes the last edit. If it added, removed or moved a slide, shows
    /// that slide, so undoing a delete brings you to the slide it restored.
    @discardableResult
    public func undo() async -> Bool {
        await showingChangedSlide { await serialized { document in try document.undo() } }
    }

    @discardableResult
    public func redo() async -> Bool {
        await showingChangedSlide { await serialized { document in try document.redo() } }
    }

    private func showingChangedSlide(_ change: () async -> Bool) async -> Bool {
        let before = SlideIdentity.ids(structure.slides)
        guard await change() else { return false }
        let after = SlideIdentity.ids(structure.slides)
        if let changed = SlideIdentity.firstDifference(before: before, after: after) {
            showSlide(min(changed, max(0, after.count - 1)))
        }
        return true
    }

    /// Writes the deck as it is now. Unchanged decks go back out byte for
    /// byte. An edit still in flight lands afterwards and keeps this save
    /// mark (see `perform`), so the deck then reads as dirty, as it should.
    public func save() throws {
        try document.save()
        document.markSaved()
    }

    /// Throws away unsaved edits and reloads the file from disk. Runs in turn
    /// with edits, so one in flight can't land on top of the reloaded deck.
    public func revert() async throws {
        let outcome: Result<Void, any Error> = await exclusively {
            do {
                let url = self.document.fileURL
                self.document = try await Task.detached { try DeckDocument(contentsOf: url) }.value
                self.claudeChanges.reset()
                self.lastEditedAt = nil
                self.slide = min(self.slide, max(0, self.slideCount - 1))
                self.selection = nil
                try await self.loadCanvas()
                self.onDocumentChanged?(.none)
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        try outcome.get()
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
        await exclusively { await self.perform(change) }
    }

    /// Runs `body` after every change queued before it; changes queued while
    /// it runs wait for it. `body` must not call `apply`, `undo` or `redo`
    /// (they would wait on it); it calls `perform` directly.
    func exclusively<T: Sendable>(_ body: @escaping @MainActor () async -> T) async -> T {
        let previous = editChain
        let task = Task<T, Never> { @MainActor in
            await previous?.value
            return await body()
        }
        editChain = Task { _ = await task.value }
        return await task.value
    }

    /// Applies one change now. Call only from inside `exclusively`.
    func perform(_ change: @escaping @Sendable (inout DeckDocument) throws -> EditResult) async -> Bool {
        let current = document
        do {
            var (next, result) = try await Task.detached {
                var copy = current
                let result = try change(&copy)
                return (copy, result)
            }.value
            // A save may have happened while the change was computed.
            next.adoptSavedState(of: document)
            document = next
            claudeChanges.note(result.edit) // Keeps Claude's change sets undoable on their own.
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
