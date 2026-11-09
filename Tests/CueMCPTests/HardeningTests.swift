import CueCore
import Foundation
import MCP
import Testing
@testable import CueMCP

/// Fixes from the pre-launch review: requests nobody serves, HTML cut short,
/// edits planned on a deck that changed since.
@Suite("Hardening")
struct HardeningTests {
    @Test func anAbandonedWaitDoesntSwallowTheNextRequest() async throws {
        let mailbox = RequestMailbox()
        let waiting = Task { await mailbox.next(timeout: .seconds(30)) }
        try await Task.sleep(for: .milliseconds(100))
        waiting.cancel() // Claude pressed Esc during next_request.
        #expect(await waiting.value == nil)
        let posted = await mailbox.post("Shorter headline", slide: 1, selection: nil)
        #expect(await mailbox.request(posted.id)?.status == .waiting, "still waiting for a live session")
    }

    @Test func samplingTakesTheRequestItPosted() async {
        let mailbox = RequestMailbox()
        let first = await mailbox.post("one", slide: 1, selection: nil)
        let second = await mailbox.post("two", slide: 1, selection: nil)
        #expect(await mailbox.take(waiting: second.id)?.id == second.id)
        #expect(await mailbox.request(first.id)?.status == .waiting, "the older request isn't stranded")
        #expect(await mailbox.take(waiting: second.id) == nil, "a request is taken once")
    }

    @Test func htmlCutShortIsNotWrittenBack() async throws {
        let (document, _) = try Decks.document()
        let harness = try await MCPHarness.connect(FakeHost(document))
        let cut = "<section data-cue-slide><h1>A</h1>\n" + DeckOutline.cutMarker + "200000 characters; the slide is longer. -->"
        let slide = try await harness.call("replace_slide_html", ["slide": 1, "html": .string(cut)])
        #expect(slide.isError && slide.text.contains("cut short"))
        let deck = try await harness.call("replace_deck_html", ["html": .string("<html><body>" + cut + "</section></body></html>")])
        #expect(deck.isError && deck.text.contains("cut short"))
    }

    @Test func anEditPlannedOnAnOlderDeckIsRefused() async throws {
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        let stale = document.source
        _ = try await host.apply([.replaceSlide(0, html: "<section data-cue-slide><h1>New</h1></section>")],
                                 summary: "user", client: "user", slide: 0)
        await #expect(throws: CueMCPError.deckChanged) {
            try await host.apply([.replaceSlide(0, html: "<section data-cue-slide><h1>Late</h1></section>")],
                                 summary: "claude", client: "claude-code", slide: 0, plannedOn: stale)
        }
    }
}
