import CueCore
import Foundation
import Testing
@testable import CueRender

/// Pausing a surface freezes its live embeds as stills, and resuming brings
/// them back live. Embeds can't be paused any other way.
@Suite("Freezing embeds on pause", .serialized)
@MainActor
struct EmbedFreezeTests {
    static let countsJS = """
        return { live: document.querySelectorAll('iframe[srcdoc]').length,
                 stills: document.querySelectorAll('img[data-cue-frozen]').length };
        """

    @Test func pauseSwapsEmbedsForStillsAndResumeRestoresThem() async throws {
        let harness = RendererHarness(surface: .editor)
        defer { harness.close() }
        let source = try Fixture.demoDeckSource()
        try await harness.load(source)
        let live = try #require(source.structure.slides.indices.first { source.structure.slides[$0].hasLiveContent })
        try await harness.show(ShowPosition(slide: live), finished: true)
        try await Task.sleep(for: .milliseconds(600))
        let before: [String: Int] = try await harness.evaluate(Self.countsJS)
        let embeds = try #require(before["live"])
        #expect(embeds > 0)

        harness.renderer.setPaused(true)
        try await harness.waitUntilAsync("embeds frozen") {
            let counts: [String: Int]? = try? await harness.evaluate(Self.countsJS)
            return counts?["live"] == 0 && counts?["stills"] == embeds
        }
        let src: String = try await harness.evaluate("return document.querySelector('img[data-cue-frozen]').src")
        #expect(src.hasPrefix("data:image/png;base64,"))

        harness.renderer.setPaused(false)
        try await harness.waitUntilAsync("embeds live again") {
            let counts: [String: Int]? = try? await harness.evaluate(Self.countsJS)
            return counts?["live"] == embeds && counts?["stills"] == 0
        }
    }
}
