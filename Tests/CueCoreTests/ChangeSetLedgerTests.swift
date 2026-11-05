import Foundation
import Testing
@testable import CueCore

/// Change sets from Claude: applied at once, accepted or undone one by one.
@Suite("Change set ledger")
struct ChangeSetLedgerTests {
    private func document() throws -> DeckDocument {
        let html = """
            <!doctype html><html><head></head><body>
            <section data-cue-slide><h1>First headline</h1><p>Body one</p></section>
            <section data-cue-slide><h1>Second headline</h1><p>Body two</p></section>
            </body></html>
            """
        let url = FileManager.default.temporaryDirectory.appending(path: "cue-ledger-\(UUID().uuidString).html")
        try Data(html.utf8).write(to: url)
        return try DeckDocument(contentsOf: url)
    }

    private func path(_ document: DeckDocument, _ tag: String, slide: Int) throws -> ElementPath {
        let slidePath = document.structure.slides[slide].elementPath
        return try #require(document.sourceMap.elements.first { $0.tag == tag && $0.path.starts(with: slidePath) }?.path)
    }

    /// Applies like the MCP server does: edit, then record it.
    private func claude(_ operation: EditOperation, on document: inout DeckDocument, _ ledger: inout ChangeSetLedger)
        throws -> ChangeSet {
        let before = document.source
        let result = try document.apply(operation)
        return try ledger.record(result.edit, on: before, client: "test", summary: "edit", slide: 0)
    }

    @Test func revertingRestoresTheExactBytes() throws {
        var document = try document()
        var ledger = ChangeSetLedger()
        let original = document.source
        let change = try claude(.setText(try path(document, "h1", slide: 0), "Short"), on: &document, &ledger)
        #expect(document.source.contains("Short"))
        #expect(change.excerpts.first?.before == "First headline")

        let undo = try ledger.revertEdit(for: change.id)
        let result = try document.apply(.patches(undo))
        ledger.note(result.edit)
        ledger.markReverted(change.id)
        #expect(document.source == original)
        #expect(ledger.change(change.id)?.status == .reverted)
    }

    @Test func eachChangeSetUndoesOnItsOwn() throws {
        var document = try document()
        var ledger = ChangeSetLedger()
        let first = try claude(.setText(try path(document, "h1", slide: 0), "One"), on: &document, &ledger)
        let second = try claude(.setText(try path(document, "p", slide: 1), "Two"), on: &document, &ledger)
        // Undo the first while the second (later in the file) stays.
        let result = try document.apply(.patches(try ledger.revertEdit(for: first.id)))
        ledger.note(result.edit)
        ledger.markReverted(first.id)
        #expect(document.source.contains("First headline"))
        #expect(document.source.contains(">Two<"))
        // The second still undoes exactly, its ranges shifted by the first's undo.
        let again = try document.apply(.patches(try ledger.revertEdit(for: second.id)))
        ledger.note(again.edit)
        #expect(document.source.contains("Body two"))
    }

    @Test func aLaterEditToTheSameTextBlocksTheUndo() throws {
        var document = try document()
        var ledger = ChangeSetLedger()
        let path = try path(document, "h1", slide: 0)
        let change = try claude(.setText(path, "Claude's"), on: &document, &ledger)
        let mine = try document.apply(.setText(path, "Mine instead"))
        ledger.note(mine.edit)
        #expect(ledger.change(change.id)?.status == .superseded)
        #expect(throws: ChangeSetError.self) { try ledger.revertEdit(for: change.id) }
    }

    @Test func acceptKeepsTheChange() throws {
        var document = try document()
        var ledger = ChangeSetLedger()
        let change = try claude(.setNotes(slide: 0, text: "New notes"), on: &document, &ledger)
        try ledger.accept(change.id)
        #expect(ledger.change(change.id)?.status == .accepted)
        #expect(ledger.pending.isEmpty)
        #expect(throws: ChangeSetError.self) { try ledger.revertEdit(for: change.id) }
    }

    @Test func replacingASlideNeedsTheSameKindOfElement() throws {
        var document = try document()
        #expect(throws: EditError.self) { try document.apply(.replaceSlide(0, html: "<div>nope</div>")) }
        try document.apply(.replaceSlide(0, html: "<section data-cue-slide><h1>Replaced</h1></section>"))
        #expect(document.structure.slides.count == 2)
        #expect(document.source.contains("<h1>Replaced</h1>"))
    }
}
