import CueCore
import Foundation

/// Edits from Claude (over MCP). They go through the same path as the
/// user's: live on the slide, in the undo history, never saved by
/// themselves, and recorded as one change set the user accepts or undoes.
extension EditorSession {
    public struct ClaudeEditError: Error, LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    /// Applies `operations` as one change set. The user's edits queue behind
    /// it, so none land between its operations. If any operation fails, the
    /// document (with its undo history) goes back to exactly how it was, so a
    /// tool call is all or nothing.
    public func applyClaudeChange(_ operations: [EditOperation], summary: String, client: String,
                                  slide: Int?, autoAccept: Bool) async throws -> ChangeSet {
        let outcome: Result<ChangeSet, any Error> = await exclusively {
            do {
                return .success(try await self.applyClaudeOperations(operations, summary: summary, client: client,
                                                                     slide: slide, autoAccept: autoAccept))
            } catch {
                return .failure(error)
            }
        }
        return try outcome.get()
    }

    /// The body of `applyClaudeChange`; runs inside the edit chain.
    private func applyClaudeOperations(_ operations: [EditOperation], summary: String, client: String,
                                       slide: Int?, autoAccept: Bool) async throws -> ChangeSet {
        let snapshot = document
        let before = document.source
        claudeChanges.isRecording = true
        defer { claudeChanges.isRecording = false }
        for (index, operation) in operations.enumerated() {
            guard await perform({ document in try document.apply(operation) }) else {
                let message = lastError ?? "Cue couldn't make that edit."
                if index > 0 { await restore(snapshot) }
                lastError = nil
                throw ClaudeEditError(message: message)
            }
        }
        guard let change = try claudeChanges.record(from: before, to: document.source, client: client,
                                                    summary: summary, slide: slide) else {
            throw ClaudeEditError(message: "That didn't change anything.")
        }
        if autoAccept { try claudeChanges.accept(change.id) }
        if let slide, slide != self.slide, structure.slides.indices.contains(slide) { showSlide(slide) }
        // The ledger's copy: after an auto-accept its status is "accepted",
        // so Claude isn't told the edit is waiting for review.
        return claudeChanges.all.first { $0.id == change.id } ?? change
    }

    /// Puts back a document from before a failed change, undo history and
    /// all (undoing step by step could merge into the user's own last edit),
    /// and reloads the canvas to match.
    private func restore(_ snapshot: DeckDocument) async {
        var restored = snapshot
        restored.adoptSavedState(of: document)
        document = restored
        selection = nil
        slide = min(slide, max(0, slideCount - 1))
        try? await loadCanvas()
        onDocumentChanged?(.none)
    }

    public func acceptClaudeChange(_ id: String) throws {
        try claudeChanges.accept(id)
    }

    /// Undoes one change set, even with later edits elsewhere in the deck.
    public func revertClaudeChange(_ id: String) async throws {
        let edit = try claudeChanges.revertEdit(for: id)
        guard await apply(.patches(edit)) else {
            throw ClaudeEditError(message: lastError ?? "Cue couldn't undo that change.")
        }
        claudeChanges.markReverted(id)
    }
}
