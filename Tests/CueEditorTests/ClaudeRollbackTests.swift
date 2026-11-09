import CueCore
@testable import CueEditor
import Foundation
import Testing

/// A failed Claude change puts the deck back exactly, and edits queue
/// behind a Claude change instead of landing in the middle of it.
@Suite("Claude change rollback", .serialized)
@MainActor
struct ClaudeRollbackTests {
    private func open() async throws -> SessionHarness {
        let document = try await EditorFixture.document(try EditorFixture.copy("cue-convention.html"))
        let harness = SessionHarness(document)
        try await harness.load(slide: 0)
        return harness
    }

    private func headingPath(_ session: EditorSession) throws -> ElementPath {
        try #require(session.document.sourceMap.elements.first { $0.tag == "h1" }).path
    }

    @Test func failedChangeKeepsTheUsersEarlierEdit() async throws {
        let harness = try await open()
        let session = harness.session
        let heading = try headingPath(session)
        #expect(await session.apply(.setText(heading, "Typed by the user")))
        let sourceBefore = session.document.source
        let undoCountBefore = session.document.history.undoCount

        // Same element, within the coalescing window: Claude's first edit
        // merges into the user's undo step. The second one is refused.
        await #expect(throws: EditorSession.ClaudeEditError.self) {
            try await session.applyClaudeChange(
                [.setText(heading, "Written by Claude"), .setAttribute(heading, name: "data-cue-id", value: "x")],
                summary: "test", client: "test", slide: nil, autoAccept: true
            )
        }
        #expect(session.document.source == sourceBefore)
        #expect(session.document.history.undoCount == undoCountBefore)
        #expect(session.claudeChanges.all.isEmpty)

        // Undo still reverses the user's own edit, and only it.
        #expect(await session.undo())
        #expect(!session.document.source.contains("Typed by the user"))
        #expect(session.document.source.contains("Hello, Cue"))
    }

    @Test func userEditsWaitForClaudesChange() async throws {
        let harness = try await open()
        let session = harness.session
        let heading = try headingPath(session)
        let claude = Task { @MainActor in
            try await session.applyClaudeChange(
                [.setText(heading, "Claude one"), .setText(heading, "Claude two")],
                summary: "test", client: "test", slide: nil, autoAccept: true
            )
        }
        await Task.yield()
        let user = Task { @MainActor in await session.apply(.setNotes(slide: 0, text: "User notes")) }
        let change = try await claude.value
        #expect(await user.value)

        // The change set holds only Claude's edit; undoing it leaves the user's.
        try await session.revertClaudeChange(change.id)
        #expect(session.document.source.contains("User notes"))
        #expect(session.document.source.contains("Hello, Cue"))
    }

    @Test func revertWaitsForAnEditInFlight() async throws {
        let harness = try await open()
        let session = harness.session
        let heading = try headingPath(session)
        let edit = Task { @MainActor in await session.apply(.setText(heading, "Not saved")) }
        await Task.yield() // The edit joins the chain first.
        try await session.revert()
        _ = await edit.value
        // The edit landed before the revert, so the revert threw it away.
        #expect(!session.document.source.contains("Not saved"))
        #expect(!session.isDirty)
    }

    @Test func saveDuringAnEditKeepsItsMark() async throws {
        let harness = try await open()
        let session = harness.session
        let heading = try headingPath(session)
        #expect(await session.apply(.setText(heading, "Saved text")))
        let edit = Task { @MainActor in await session.apply(.setNotes(slide: 0, text: "After the save")) }
        await Task.yield()
        try session.save()
        #expect(await edit.value)
        #expect(session.isDirty)
        // Undoing the later edit returns to what was saved.
        #expect(await session.undo())
        #expect(!session.isDirty)
    }
}
