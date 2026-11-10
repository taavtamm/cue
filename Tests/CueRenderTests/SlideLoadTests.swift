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
          <script>
            addEventListener('test-redraw-burst', () => { for (let i = 0; i < 50; i += 1) requestAnimationFrame(() => {}); });
          </script>
        </section>
        <section data-cue-slide id="calm"><h1>Still</h1></section>
        </body></html>
        """

    @Test func measuresBlursLoopsEmbedsAndRedraws() async throws {
        let harness = RendererHarness(surface: .editor)
        defer { harness.close() }
        try await harness.load(try Fixture.deck(html: Self.heavy))
        try await harness.show(ShowPosition(slide: 0), finished: true)
        // Off screen WebKit runs no frames and slows timers, so the deck is
        // told to ask for 50 frames at once, again and again until the
        // measurement is done; some bursts always land inside it.
        let measuring = Task { try await harness.renderer.load(onSlide: 0, slideSelector: "[data-cue-slide]") }
        let bursts = Task {
            while !Task.isCancelled {
                _ = try? await harness.renderer.evaluateInBridge("window.dispatchEvent(new Event('test-redraw-burst'))")
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        let load = try #require(try await measuring.value)
        bursts.cancel()
        #expect(load.blurs == 3, "the zero-size blur doesn't count")
        #expect(load.loopingAnimations == 2, "the animation that ends doesn't count")
        #expect(load.embeds == 1)
        #expect(load.redrawsPerSecond >= 30, "the requests are counted: \(load.redrawsPerSecond)")
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
