import Foundation

/// Undo and redo as patches. Undoing applies the inverse patch, which puts
/// back the exact characters that were there, so the bytes match too.
public struct EditHistory: Sendable {
    struct Record: Sendable {
        let operation: EditOperation
        var forward: SourceEdit
        var inverse: SourceEdit
        let plan: LivePlan
        var time: Date
    }

    /// Typing into the same element within this long counts as one edit.
    public var coalescingInterval: TimeInterval = 1.5
    private(set) var undoStack: [Record] = []
    private(set) var redoStack: [Record] = []

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoCount: Int { undoStack.count }
    /// The patches of the edit Undo would reverse, for tests and diagnostics.
    public var lastForward: SourceEdit? { undoStack.last?.forward }

    mutating func record(_ record: Record) {
        redoStack.removeAll()
        if var last = undoStack.last, let merged = Self.merge(last, record, within: coalescingInterval) {
            last = merged
            undoStack[undoStack.count - 1] = last
        } else {
            undoStack.append(record)
        }
    }

    mutating func popUndo() -> Record? {
        guard let record = undoStack.popLast() else { return nil }
        redoStack.append(record)
        return record
    }

    mutating func popRedo() -> Record? {
        guard let record = redoStack.popLast() else { return nil }
        undoStack.append(record)
        return record
    }

    /// Two single-patch edits of the same thing, where the second replaces
    /// exactly what the first wrote, become one: first's old text → second's new text.
    private static func merge(_ first: Record, _ second: Record, within interval: TimeInterval) -> Record? {
        guard let key = first.operation.coalescingKey, key == second.operation.coalescingKey,
              second.time.timeIntervalSince(first.time) <= interval,
              first.forward.patches.count == 1, second.forward.patches.count == 1,
              first.inverse.patches.count == 1, second.inverse.patches.count == 1,
              second.forward.patches[0].range == first.inverse.patches[0].range
        else { return nil }
        var merged = second
        merged.forward = SourceEdit([SourcePatch(range: first.forward.patches[0].range,
                                                 replacement: second.forward.patches[0].replacement)])
        merged.inverse = SourceEdit([SourcePatch(range: second.inverse.patches[0].range,
                                                 replacement: first.inverse.patches[0].replacement)])
        return merged
    }
}
