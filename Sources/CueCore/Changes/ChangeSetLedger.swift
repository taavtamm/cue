import Foundation

/// The change sets made in one editing session, and the bookkeeping that
/// lets each be undone on its own later.
///
/// Every edit to the deck after a change set (the user's own, Claude's
/// next one, undo, redo) must be passed to `note(_:)`. Edits elsewhere in
/// the file only shift the change set's ranges; an edit touching its text
/// marks it superseded, because undoing it then would mangle the newer edit.
public struct ChangeSetLedger: Sendable {
    public private(set) var changes: [ChangeSet] = []
    private var counter = 0

    public init() {}

    public var pending: [ChangeSet] { changes.filter { $0.status == .pending } }

    public func change(_ id: String) -> ChangeSet? { changes.first { $0.id == id } }

    /// Records an edit just applied. `result.edit` is in the offsets of the
    /// text before it; the inverse comes out in the offsets after it.
    @discardableResult
    public mutating func record(_ applied: SourceEdit, on source: String, client: String, summary: String,
                                slide: Int?) throws -> ChangeSet {
        let (_, inverse) = try applied.apply(to: source)
        counter += 1
        note(applied) // Earlier change sets shift past this one.
        let change = ChangeSet(id: "cs-\(counter)", client: client, summary: summary, slide: slide,
                               applied: applied, inverse: inverse, source: source)
        changes.append(change)
        return change
    }

    /// Any other edit to the deck, in the offsets of the text before it.
    public mutating func note(_ edit: SourceEdit) {
        guard !edit.isEmpty else { return }
        for index in changes.indices where changes[index].status == .pending || changes[index].status == .accepted {
            guard let shifted = Self.shift(changes[index].inverse, past: edit) else {
                if changes[index].status == .pending { changes[index].status = .superseded }
                continue
            }
            changes[index].inverse = shifted
        }
    }

    public mutating func accept(_ id: String) throws {
        guard let index = changes.firstIndex(where: { $0.id == id }) else { throw ChangeSetError.unknown(id) }
        guard changes[index].status == .pending else { throw ChangeSetError.notPending(id, changes[index].status) }
        changes[index].status = .accepted
    }

    /// The edit that undoes a pending change set. Apply it as `.patches`,
    /// pass it to `note(_:)` like any edit, then call `markReverted`.
    public func revertEdit(for id: String) throws -> SourceEdit {
        guard let change = change(id) else { throw ChangeSetError.unknown(id) }
        // Kept changes can be undone too, until later edits touch the same text.
        guard change.status == .pending || change.status == .accepted else {
            throw ChangeSetError.notPending(id, change.status)
        }
        return change.inverse
    }

    public mutating func markReverted(_ id: String) {
        guard let index = changes.firstIndex(where: { $0.id == id }) else { return }
        changes[index].status = .reverted
    }

    /// `ranges` moved past `edit`, or nil when they overlap it.
    static func shift(_ ranges: SourceEdit, past edit: SourceEdit) -> SourceEdit? {
        var moved: [SourcePatch] = []
        for patch in ranges.patches {
            var delta = 0
            for other in edit.patches {
                if overlaps(patch.range, other.range) { return nil }
                if other.range.end <= patch.range.start { delta += other.replacement.utf16.count - other.range.length }
            }
            moved.append(SourcePatch(range: SourceRange(start: patch.range.start + delta, end: patch.range.end + delta),
                                     replacement: patch.replacement))
        }
        return SourceEdit(moved)
    }

    /// Ranges that share text, or an insert inside (or at the edges of) a range.
    static func overlaps(_ a: SourceRange, _ b: SourceRange) -> Bool {
        if a.length == 0 || b.length == 0 {
            return (a.start >= b.start && a.start <= b.end) || (b.start >= a.start && b.start <= a.end)
        }
        return a.start < b.end && b.start < a.end
    }
}

public enum ChangeSetError: Error, Equatable, LocalizedError {
    case unknown(String)
    case notPending(String, ChangeSet.Status)

    public var errorDescription: String? {
        switch self {
        case .unknown(let id): "There's no change set \(id)."
        case .notPending(let id, .superseded):
            "Change set \(id) can't be undone on its own: later edits changed the same text. Use Edit › Undo instead."
        case .notPending(let id, let status): "Change set \(id) is already \(status.rawValue)."
        }
    }
}
