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

    /// Applies `operations` as one change set. If any fails, the ones before
    /// it are undone, so a tool call is all or nothing.
    public func applyClaudeChange(_ operations: [EditOperation], summary: String, client: String,
                                  slide: Int?, autoAccept: Bool) async throws -> ChangeSet {
        let before = document.source
        claudeChanges.isRecording = true
        defer { claudeChanges.isRecording = false }
        var applied = 0
        for operation in operations {
            guard await apply(operation) else {
                let message = lastError ?? "Cue couldn't make that edit."
                for _ in 0..<applied { _ = await undo() }
                lastError = nil
                throw ClaudeEditError(message: message)
            }
            applied += 1
        }
        guard let change = try claudeChanges.record(from: before, to: document.source, client: client,
                                                    summary: summary, slide: slide) else {
            throw ClaudeEditError(message: "That didn't change anything.")
        }
        if autoAccept { try claudeChanges.accept(change.id) }
        if let slide, slide != self.slide, structure.slides.indices.contains(slide) { showSlide(slide) }
        return change
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
