import Foundation

extension ChangeSetLedger {
    /// Records everything that changed between `before` and `after` as one
    /// change set: a tool call may run several edits, the user sees one.
    @discardableResult
    public mutating func record(from before: String, to after: String, client: String, summary: String,
                                slide: Int?) throws -> ChangeSet? {
        let edit = SourceEdit.difference(from: before, to: after)
        guard !edit.isEmpty else { return nil }
        return try record(edit, on: before, client: client, summary: summary, slide: slide)
    }
}

extension SourceEdit {
    /// The single patch that turns `old` into `new`: everything between the
    /// longest common start and end. UTF-16 offsets, like every patch.
    public static func difference(from old: String, to new: String) -> SourceEdit {
        let a = Array(old.utf16), b = Array(new.utf16)
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix,
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        let range = SourceRange(start: prefix, end: a.count - suffix)
        let replacement = String(decoding: b[prefix..<(b.count - suffix)], as: UTF16.self)
        if range.length == 0 && replacement.isEmpty { return SourceEdit([]) }
        return SourceEdit([SourcePatch(range: range, replacement: replacement)])
    }
}
