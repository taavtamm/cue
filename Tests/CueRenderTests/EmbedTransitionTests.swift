import CueCore
import Foundation
import Testing
@testable import CueRender

/// The deck's embed placeholders read "Interactive web embed: not captured
/// for export". They must never be visible on a live surface, including
/// while one slide fades into the next.
@Suite("Embed placeholders during transitions", .serialized)
@MainActor
struct EmbedTransitionTests {
    /// Counts placeholders that are actually visible right now: not hidden,
    /// and on a slide whose computed opacity is above zero.
    static let visiblePlaceholdersJS = """
        return Array.from(document.querySelectorAll('[data-frame-id] > :first-child'))
          .filter((el) => el.textContent.includes('not captured for export'))
          .filter((el) => {
            const slide = el.closest('section.deck-slide');
            return getComputedStyle(el).visibility !== 'hidden'
              && slide && Number(getComputedStyle(slide).opacity) > 0;
          }).length;
        """

    @Test func placeholdersStayHiddenThroughSlideChanges() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        let source = try Fixture.demoDeckSource()
        try await harness.load(source)
        let live = source.structure.slides.indices.filter { source.structure.slides[$0].hasLiveContent }
        let pair = try #require(zip(live, live.dropFirst()).first { $0.1 == $0.0 + 1 })

        try await harness.show(ShowPosition(slide: pair.0))
        try await Task.sleep(for: .milliseconds(500))

        for target in [pair.1, pair.0] { // forward, then back
            harness.renderer.show(ShowPosition(slide: target))
            var worst = 0
            for _ in 0..<20 { // ~700 ms, longer than any transition
                let visible: Int = try await harness.evaluate(Self.visiblePlaceholdersJS)
                worst = max(worst, visible)
                try await Task.sleep(for: .milliseconds(35))
            }
            #expect(worst == 0, "a placeholder showed while moving to slide \(target + 1)")
        }
    }

    @Test func outgoingEmbedsAreRemovedOnceTheTransitionEnds() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        let source = try Fixture.demoDeckSource()
        try await harness.load(source)
        let live = try #require(source.structure.slides.indices.first { source.structure.slides[$0].hasLiveContent })

        try await harness.show(ShowPosition(slide: live))
        harness.renderer.show(ShowPosition(slide: live + 1))
        try await Task.sleep(for: .milliseconds(900))
        let leftOver: Int = try await harness.evaluate(PlayerTests.embedCountJS(slide: live))
        #expect(leftOver == 0)
    }
}
