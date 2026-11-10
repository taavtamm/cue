import CueCore
import Foundation
import Testing
@testable import CueRender

/// Cue measures what keeps the GPU busy on the live page: visible blurs,
/// endless animations, embeds and the deck's own redraws.
@Suite("Slide load", .serialized)
@MainActor
struct SlideLoadTests {
    static let heavy = """
        <!doctype html><html><head><meta name="cue:canvas" content="1280x720"><style>
        @keyframes spin { to { transform: rotate(360deg); } }
        .glass { width: 100px; height: 100px; backdrop-filter: blur(20px); }
        .hidden-glass { width: 0; height: 0; backdrop-filter: blur(20px); }
        .spin { width: 20px; height: 20px; animation: spin 1s linear infinite; }
        .once { width: 20px; height: 20px; animation: spin 1s linear 1; }
        </style></head><body>
        <section data-cue-slide id="busy">
          <div class="glass"></div><div class="glass"></div><div class="glass"></div><div class="hidden-glass"></div>
          <div class="spin"></div><div class="spin"></div><div class="once"></div>
          <iframe srcdoc="<p>embed</p>"></iframe>
          <script>setInterval(() => requestAnimationFrame(() => {}), 10);</script>
        </section>
        <section data-cue-slide id="calm"><h1>Still</h1></section>
        </body></html>
        """

    @Test func measuresBlursLoopsEmbedsAndRedraws() async throws {
        let harness = RendererHarness(surface: .editor)
        defer { harness.close() }
        try await harness.load(try Fixture.deck(html: Self.heavy))
        try await harness.show(ShowPosition(slide: 0), finished: true)
        let load = try #require(try await harness.renderer.load(onSlide: 0, slideSelector: "[data-cue-slide]"))
        #expect(load.blurs == 3, "the zero-size blur doesn't count")
        #expect(load.loopingAnimations == 2, "the animation that ends doesn't count")
        #expect(load.embeds == 1)
        // Off screen WebKit runs no frames and slows timers, so the deck asks
        // for frames from a timer here, and fewer arrive than on screen.
        #expect(load.redrawsPerSecond >= 4, "the deck's redraw requests are counted: \(load.redrawsPerSecond)")
        #expect(load.isHeavy)
    }

    @Test func aStillSlideIsLight() async throws {
        let harness = RendererHarness(surface: .editor)
        defer { harness.close() }
        try await harness.load(try Fixture.deck(html: Self.heavy))
        try await harness.show(ShowPosition(slide: 1), finished: true)
        let load = try #require(try await harness.renderer.load(onSlide: 1, slideSelector: "[data-cue-slide]"))
        #expect(load.blurs == 0 && load.loopingAnimations == 0 && load.embeds == 0)
        #expect(!load.isHeavy, "\(load.reasons)")
    }
}
