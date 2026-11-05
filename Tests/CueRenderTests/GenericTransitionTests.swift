import CueCore
import Foundation
import Testing
@testable import CueRender

/// Cue-convention decks carry `data-cue-transition` on a slide; the generic
/// player plays it when moving on, like the Claude Design player does.
@Suite("Generic player transitions", .serialized)
@MainActor
struct GenericTransitionTests {
    static func deck(_ kind: String) -> String {
        """
        <!doctype html><html><head><meta name="cue:canvas" content="1280x720"></head><body>
        <section data-cue-slide id="a" data-cue-transition="\(kind)"><h1>One</h1></section>
        <section data-cue-slide id="b"><h1>Two</h1></section>
        </body></html>
        """
    }

    static let stateJS = """
        const a = document.getElementById('a');
        return { leaving: a.hasAttribute('data-cue-leaving'), animations: a.getAnimations().length + document.getElementById('b').getAnimations().length };
        """

    @Test(arguments: ["fade", "push"])
    func playsTheSlidesTransition(kind: String) async throws {
        let harness = RendererHarness(surface: .stage)
        defer { harness.close() }
        try await harness.load(try Fixture.deck(html: Self.deck(kind)))
        try await harness.show(ShowPosition(slide: 0))
        harness.renderer.show(ShowPosition(slide: 1))
        try await harness.waitUntilAsync("the transition is playing") {
            let state: [String: Any]? = try? await harness.evaluate(Self.stateJS)
            return state?["leaving"] as? Bool == true && (state?["animations"] as? Int ?? 0) > 0
        }
        try await harness.waitUntilAsync("it finishes and the old slide is gone") {
            let state: [String: Any]? = try? await harness.evaluate(Self.stateJS)
            return state?["leaving"] as? Bool == false
        }
    }

    @Test func jumpsAndTheEditorsFinishedStateDontAnimate() async throws {
        let harness = RendererHarness(surface: .stage)
        defer { harness.close() }
        try await harness.load(try Fixture.deck(html: Self.deck("fade")))
        try await harness.show(ShowPosition(slide: 0))
        try await harness.show(ShowPosition(slide: 1), finished: true)
        let state: [String: Any] = try await harness.evaluate(Self.stateJS)
        #expect(state["leaving"] as? Bool == false)
    }
}
