import Foundation

/// One text replacement on the deck's source: `range` (UTF-16 offsets, as
/// parse5 reports them) becomes `replacement`. Every edit Cue makes is a
/// small set of these, so the file changes only where the user changed it.
public struct SourcePatch: Sendable, Equatable, Codable {
    public var range: SourceRange
    public var replacement: String

    public init(range: SourceRange, replacement: String) {
        self.range = range
        self.replacement = replacement
    }

    public static func insert(_ text: String, at offset: Int) -> SourcePatch {
        SourcePatch(range: SourceRange(start: offset, end: offset), replacement: text)
    }

    public static func delete(_ range: SourceRange) -> SourcePatch {
        SourcePatch(range: range, replacement: "")
    }
}

/// Patches applied together. Ranges refer to the text *before* the edit and
/// must not overlap.
public struct SourceEdit: Sendable, Equatable, Codable {
    public var patches: [SourcePatch]

    public init(_ patches: [SourcePatch]) {
        // Inserts before replacements that start at the same offset.
        self.patches = patches.sorted { ($0.range.start, $0.range.end) < ($1.range.start, $1.range.end) }
    }

    public var isEmpty: Bool { patches.allSatisfy { $0.range.length == 0 && $0.replacement.isEmpty } }

    /// Applies the patches and returns the new text with the edit that undoes them.
    public func apply(to text: String) throws -> (text: String, inverse: SourceEdit) {
        var units = Array(text.utf16)
        let originalCount = units.count
        var inverse: [SourcePatch] = []
        var shift = 0 // How far earlier patches moved later offsets.
        var previousEnd = 0
        for patch in patches {
            guard patch.range.start >= previousEnd, patch.range.end <= originalCount, patch.range.length >= 0 else {
                throw EditError.patchOutOfRange
            }
            previousEnd = patch.range.end
            let old = String(decoding: units[(patch.range.start + shift)..<(patch.range.end + shift)], as: UTF16.self)
            let new = Array(patch.replacement.utf16)
            let start = patch.range.start + shift
            units.replaceSubrange(start..<(patch.range.end + shift), with: new)
            inverse.append(SourcePatch(range: SourceRange(start: start, end: start + new.count), replacement: old))
            shift += new.count - patch.range.length
        }
        return (String(decoding: units, as: UTF16.self), SourceEdit(inverse))
    }

    /// The smallest range of the *old* text that contains every patch.
    public var touchedRange: SourceRange? {
        guard let first = patches.first, let last = patches.last else { return nil }
        return SourceRange(start: first.range.start, end: last.range.end)
    }
}
