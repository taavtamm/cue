import CueCore
import Foundation
import Testing
@testable import CueRender

/// The generic player, passthrough mode and the network block, on small decks.
@Suite("Other decks and the sandbox", .serialized)
@MainActor
struct ModesTests {
    static let cueDeck = """
        <!doctype html><html><head><meta name="cue:canvas" content="1280x720"></head><body>
        <section data-cue-slide id="a"><h1>One</h1></section>
        <section data-cue-slide id="b"><h1>Two</h1><p data-cue-build="1" id="point">Point</p></section>
        <section data-cue-slide id="c"><h1>Three</h1></section>
        </body></html>
        """

    static let revealLikeDeck = """
        <!doctype html><html><body><div class="reveal"><div class="slides">
        <section class="present">A</section><section>B</section><section>C</section>
        </div></div><script>
        const slides = Array.from(document.querySelectorAll('.slides > section'));
        let i = 0;
        const go = (n) => {
          slides[i].classList.remove('present');
          i = Math.max(0, Math.min(slides.length - 1, n));
          slides[i].classList.add('present');
        };
        document.addEventListener('keydown', (e) => {
          if (e.key === 'ArrowRight') go(i + 1);
          if (e.key === 'ArrowLeft') go(i - 1);
          if (e.key === 'Home') go(0);
        });
        </script></body></html>
        """

    @Test func genericPlayerShowsOneSlideAndHidesUnrevealedBuilds() async throws {
        let size = CGSize(width: 1000, height: 1000)
        let harness = RendererHarness(size: size)
        defer { harness.close() }
        let source = try Fixture.deck(html: Self.cueDeck)
        #expect(source.structure.adapter == .cue)
        try await harness.load(source)
        #expect(harness.renderer.slideCount == 3)

        try await harness.show(ShowPosition(slide: 1, build: 0))
        let state: [String: Any] = try await harness.evaluate("""
            const visible = Array.from(document.querySelectorAll('[data-cue-slide]'))
              .filter((s) => getComputedStyle(s).display !== 'none').map((s) => s.id);
            const r = document.getElementById('b').getBoundingClientRect();
            const point = getComputedStyle(document.getElementById('point')).visibility;
            return { visible, point, w: r.width, x: r.x, y: r.y };
            """)
        #expect(state["visible"] as? [String] == ["b"])
        #expect(state["point"] as? String == "hidden")
        #expect(abs((state["w"] as? Double ?? 0) - 1000) < 1)
        #expect(abs((state["y"] as? Double ?? 0) - (1000 - 562.5) / 2) < 1)

        try await harness.show(ShowPosition(slide: 1, build: 1))
        try await Task.sleep(for: .milliseconds(50))
        let point: String = try await harness.evaluate(
            "return getComputedStyle(document.getElementById('point')).visibility")
        #expect(point == "visible")
    }

    @Test func passthroughForwardsKeysAndReportsTheSlide() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        let source = try Fixture.deck(html: Self.revealLikeDeck)
        #expect(source.structure.renderMode == .passthrough)
        try await harness.load(source)

        harness.renderer.show(ShowPosition(slide: 1))
        try await harness.waitUntil("page reports slide 2") {
            harness.events.contains(.position(ShowPosition(slide: 1)))
        }
        harness.renderer.show(ShowPosition(slide: 2))
        try await harness.waitUntil("page reports slide 3") {
            harness.events.contains(.position(ShowPosition(slide: 2)))
        }
        let present: String = try await harness.evaluate("return document.querySelector('.present').textContent")
        #expect(present == "C")
    }

    /// The deck moves on by itself (a click, a timer); Swift follows and
    /// echoes that slide back. The echo must not press → a second time.
    @Test func passthroughDoesNotReplayTheDecksOwnNavigation() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        try await harness.load(try Fixture.deck(html: Self.revealLikeDeck))
        _ = try await harness.renderer.evaluateInPage("go(1)")
        try await harness.waitUntil("the deck reports slide 2") {
            harness.events.contains { if case .position(let p) = $0 { p.slide == 1 } else { false } }
        }
        harness.renderer.show(ShowPosition(slide: 1)) // What ShowSession sends after following.
        try await Task.sleep(for: .milliseconds(300))
        let present: Int = try await harness.evaluate(
            "return Array.from(document.querySelectorAll('.slides > section')).findIndex((s) => s.classList.contains('present'))"
        )
        #expect(present == 1)
    }

    @Test func deckScriptsCannotReachTheNetworkOpenWindowsOrSeeTheBridge() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        try await harness.load(try Fixture.deck(html: Self.cueDeck))

        let fetched = try await harness.renderer.evaluateInPage("""
            try { await fetch('https://example.com/'); return 'loaded'; } catch (e) { return 'blocked'; }
            """) as? String
        #expect(fetched == "blocked")
        let opened = try await harness.renderer.evaluateInPage(
            "return window.open('https://example.com') === null") as? Bool
        #expect(opened == true)
        let seesBridge = try await harness.renderer.evaluateInPage(
            "return typeof window.__cue !== 'undefined' || !!window.webkit?.messageHandlers?.cue"
        ) as? Bool
        #expect(seesBridge == false)
        let readsFile = try await harness.renderer.evaluateInPage("""
            try { await fetch('file:///etc/hosts'); return 'read'; } catch (e) { return 'blocked'; }
            """) as? String
        #expect(readsFile == "blocked")
        let escapes = try await harness.renderer.evaluateInPage("""
            const r = await fetch('cue-deck://deck/..%2F..%2F..%2Fetc%2Fhosts'); return r.status;
            """) as? Int
        #expect(escapes == 403)
    }
}
