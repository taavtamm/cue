import Foundation
import Testing
@testable import CueCore

@Suite("Undo and redo")
struct UndoTests {
    @Test func undoAndRedoReplayExactBytes() throws {
        var document = try Editing.document("cue-convention.html")
        let original = document.source
        let h1 = try Editing.path(in: document, tag: "h1")
        let start = Date()
        try document.apply(.setText(h1, "One"), at: start)
        let afterOne = document.source
        try document.apply(.moveSlide(from: 0, to: 2), at: start.addingTimeInterval(10))
        let afterMove = document.source
        try document.undo()
        #expect(document.source == afterOne)
        try document.undo()
        #expect(document.source == original)
        #expect(throws: EditError.nothingToUndo) { try document.undo() }
        try document.redo()
        try document.redo()
        #expect(document.source == afterMove)
    }

    @Test func typingCoalescesIntoOneUndo() throws {
        var document = try Editing.document("cue-convention.html")
        let original = document.source
        let h1 = try Editing.path(in: document, tag: "h1")
        let start = Date()
        for (index, text) in ["H", "He", "Hel", "Hello"].enumerated() {
            try document.apply(.setText(h1, text), at: start.addingTimeInterval(Double(index) * 0.3))
        }
        #expect(document.history.undoCount == 1)
        try document.apply(.setText(h1, "Later"), at: start.addingTimeInterval(30))
        #expect(document.history.undoCount == 2)
        try document.undo()
        #expect(document.source.contains("<h1>Hello</h1>"))
        try document.undo()
        #expect(document.source == original)
    }

    @Test func dirtyTracksSaves() throws {
        var document = try Editing.document("cue-convention.html")
        #expect(!document.isDirty)
        try document.apply(.setNotes(slide: 0, text: "Edited"))
        #expect(document.isDirty)
        try document.save()
        document.markSaved()
        #expect(!document.isDirty)
        #expect(try String(contentsOf: document.fileURL, encoding: .utf8) == document.source)
    }
}
