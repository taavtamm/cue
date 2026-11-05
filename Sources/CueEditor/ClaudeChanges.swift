import CueCore
import Foundation
import Observation

/// Claude's change sets for one editor window. Every edit to the deck,
/// Claude's or the user's, passes through here so each change set can still
/// be undone on its own later (see `ChangeSetLedger`).
@MainActor @Observable
public final class ClaudeChanges {
    public private(set) var ledger = ChangeSetLedger()
    /// While Claude's own edits run, they're recorded as one change set
    /// instead of being noted one by one.
    @ObservationIgnored var isRecording = false

    public init() {}

    public var all: [ChangeSet] { ledger.changes }
    public var pending: [ChangeSet] { ledger.pending }
    /// The change set the canvas banner shows.
    public var latestPending: ChangeSet? { ledger.pending.last }

    func note(_ edit: SourceEdit) {
        guard !isRecording else { return }
        ledger.note(edit)
    }

    func record(from before: String, to after: String, client: String, summary: String, slide: Int?) throws -> ChangeSet? {
        try ledger.record(from: before, to: after, client: client, summary: summary, slide: slide)
    }

    func accept(_ id: String) throws { try ledger.accept(id) }
    func revertEdit(for id: String) throws -> SourceEdit { try ledger.revertEdit(for: id) }
    func markReverted(_ id: String) { ledger.markReverted(id) }

    /// The file was reverted to disk: nothing earlier can be undone on its own.
    func reset() { ledger = ChangeSetLedger() }
}
