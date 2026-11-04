import CueCore
import Testing
@testable import CueEditor

/// Deleting and moving slides undo like any other edit, and undo shows the
/// slide it brought back.
@Suite("Undoing slide deletes and moves", .serialized)
@MainActor
struct SlideStructureUndoTests {
    @Test func undoingADeleteRestoresTheSlideAndShowsIt() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let harness = SessionHarness(document)
        defer { harness.close() }
        try await harness.load(slide: 5)
        let original = harness.session.document.source
        let deletedID = harness.session.structure.slides[2].id

        #expect(await harness.session.apply(.deleteSlide(2)))
        #expect(harness.session.slideCount == 11)
        #expect(!harness.session.structure.slides.map(\.id).contains(deletedID))

        #expect(await harness.session.undo())
        #expect(harness.session.slideCount == 12)
        #expect(harness.session.structure.slides[2].id == deletedID)
        #expect(harness.session.slide == 2, "undo shows the restored slide")
        #expect(harness.session.document.source == original, "back to the exact bytes")
    }

    @Test func undoingAMoveShowsWhereItChanged() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let harness = SessionHarness(document)
        defer { harness.close() }
        try await harness.load(slide: 0)
        #expect(await harness.session.apply(.moveSlide(from: 7, to: 3)))
        harness.session.showSlide(10)
        #expect(await harness.session.undo())
        #expect(harness.session.slide == 3)
        #expect(harness.session.structure.slides.map(\.id) == (1...12).map(String.init))
    }
}
