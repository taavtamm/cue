import Foundation
import Testing
@testable import CueCore

/// Helpers for the source-editing tests.
enum Editing {
    static func document(_ fixture: String) throws -> DeckDocument {
        try DeckDocument(contentsOf: Fixtures.copy(fixture))
    }

    static func document(html: String, named name: String = "deck.html") throws -> DeckDocument {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cue-edit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try Data(html.utf8).write(to: url)
        return try DeckDocument(contentsOf: url)
    }

    /// The first element matching `match`, in document order.
    static func path(in document: DeckDocument, where match: (MappedElement) -> Bool) throws -> ElementPath {
        let found = document.sourceMap.elements.first(where: match)
        return try #require(found).path
    }

    static func path(in document: DeckDocument, tag: String) throws -> ElementPath {
        try path(in: document) { $0.tag == tag }
    }

    /// Everything outside the edit's touched range is unchanged: the new
    /// text starts with the old text's head and ends with its tail.
    static func expectLocal(
        before: String, after: String, edit: SourceEdit, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let touched = edit.touchedRange else { return }
        let tail = before.utf16.count - touched.end
        #expect(isLocal(Array(before.utf16), Array(after.utf16), head: touched.start, tail: tail),
                "changed outside the edit", sourceLocation: sourceLocation)
    }

    /// The diff stays inside `region` of the old text (a range taken from the
    /// original file, independent of the patch).
    static func expectWithin(_ region: SourceRange?, before: String, after: String,
                             sourceLocation: SourceLocation = #_sourceLocation) {
        guard let region else {
            Issue.record("no region", sourceLocation: sourceLocation)
            return
        }
        let edit = SourceEdit([SourcePatch(range: region, replacement: "")])
        expectLocal(before: before, after: after, edit: edit, sourceLocation: sourceLocation)
    }

    /// Same check on bytes, in the file's encoding.
    static func expectLocalBytes(before: Data, after: Data, beforeText: String, edit: SourceEdit,
                                 sourceLocation: SourceLocation = #_sourceLocation) {
        guard let touched = edit.touchedRange else { return }
        let (head, tail) = byteLengths(around: touched, in: beforeText, bom: before.count - beforeText.utf8.count)
        #expect(isLocal(Array(before), Array(after), head: head, tail: tail), "bytes changed outside the edit",
                sourceLocation: sourceLocation)
    }

    /// UTF-8 byte lengths of the text before and after `range`; `bom` bytes count as head.
    static func byteLengths(around range: SourceRange, in text: String, bom: Int = 0) -> (head: Int, tail: Int) {
        let units = Array(text.utf16)
        let head = String(decoding: units[0..<range.start], as: UTF16.self).utf8.count + bom
        let tail = String(decoding: units[range.end...], as: UTF16.self).utf8.count
        return (head, tail)
    }

    /// `new` keeps `old`'s first `head` and last `tail` elements.
    static func isLocal<T: Equatable>(_ old: [T], _ new: [T], head: Int, tail: Int) -> Bool {
        head + tail <= old.count && head + tail <= new.count
            && old.prefix(head).elementsEqual(new.prefix(head)) && old.suffix(tail).elementsEqual(new.suffix(tail))
    }
}
