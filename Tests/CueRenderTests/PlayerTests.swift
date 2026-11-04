import CueCore
import Foundation
import Testing
@testable import CueRender

/// Real WKWebView tests on the Fernwick fixture.
@Suite("Universal player on the Fernwick deck", .serialized)
@MainActor
struct PlayerTests {
    /// For each slide: is it showing, and where is its 1920×1080 canvas on screen.
    static let slideLayoutJS = """
        return Array.from(document.querySelectorAll('section.deck-slide')).map((slide) => {
          const style = getComputedStyle(slide);
          const showing = !slide.hasAttribute('data-off') && style.opacity !== '0'
            && style.visibility !== 'hidden' && style.display !== 'none';
          const r = (slide.querySelector('.deck-fit') || slide).getBoundingClientRect();
          return { showing, x: r.x, y: r.y, w: r.width, h: r.height };
        });
        """

    static func embedCountJS(slide: Int) -> String {
        "return document.querySelectorAll('section.deck-slide')[\(slide)].querySelectorAll('iframe[srcdoc]').length"
    }

    @Test func reportsTwelveSlidesAndUsesTheClaudeDesignPlayer() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        try await harness.load(try Fixture.demo-deckSource())

        #expect(harness.renderer.slideCount == 12)
        let player: String = try await harness.evaluate("return window.__cue.debug().player")
        #expect(player == "claudeDesign")
        let deckPlayerRan: Bool = try await harness.evaluate(
            "return document.documentElement.outerHTML.includes('function yCn(')")
        #expect(!deckPlayerRan)
    }

    @Test func everySlideShowsAloneScaledToFitAndCentred() async throws {
        let size = CGSize(width: 1280, height: 800)
        let harness = RendererHarness(size: size)
        defer { harness.close() }
        try await harness.load(try Fixture.demo-deckSource())

        let scale = min(size.width / 1920, size.height / 1080)
        for slide in 0..<12 {
            try await harness.show(ShowPosition(slide: slide), finished: true)
            let layout: [[String: Any]] = try await harness.evaluate(Self.slideLayoutJS)
            let showing = layout.indices.filter { layout[$0]["showing"] as? Bool == true }
            #expect(showing == [slide], "slide \(slide + 1): showing \(showing)")

            let rect = layout[slide]
            let width = rect["w"] as? Double ?? 0, height = rect["h"] as? Double ?? 0
            let x = rect["x"] as? Double ?? 0, y = rect["y"] as? Double ?? 0
            let fits = abs(width - 1920 * scale) < 1 && abs(height - 1080 * scale) < 1
            let centred = abs(x - (size.width - width) / 2) < 1 && abs(y - (size.height - height) / 2) < 1
            #expect(fits, "slide \(slide + 1) size \(width)×\(height)")
            #expect(centred, "slide \(slide + 1) at \(x),\(y)")
        }
    }

    @Test func liveEmbedsRunOnTheirSlidesOnly() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        let source = try Fixture.demo-deckSource()
        try await harness.load(source)

        let liveSlides = source.structure.slides.indices.filter { source.structure.slides[$0].hasLiveContent }
        #expect(!liveSlides.isEmpty)
        for slide in [0] + liveSlides {
            try await harness.show(ShowPosition(slide: slide), finished: true)
            try await Task.sleep(for: .milliseconds(150))
            let frames: Int = try await harness.evaluate("return document.querySelectorAll('iframe[srcdoc]').length")
            let onSlide: Int = try await harness.evaluate(
                Self.embedCountJS(slide: slide))
            #expect(frames == onSlide, "slide \(slide + 1): every iframe belongs to the showing slide")
            #expect((onSlide > 0) == liveSlides.contains(slide), "slide \(slide + 1) has \(onSlide) embeds")
        }

        let reported = harness.events.compactMap { event -> [Int]? in
            if case .liveContent(let slides) = event { return slides } else { return nil }
        }.first ?? []
        #expect(Set(liveSlides).isSubset(of: Set(reported)))
    }

    @Test func embedsAreSandboxedAndAnimate() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        let source = try Fixture.demo-deckSource()
        try await harness.load(source)
        let liveIndex = source.structure.slides.firstIndex { $0.hasLiveContent }
        let live = try #require(liveIndex)
        try await harness.show(ShowPosition(slide: live))
        try await Task.sleep(for: .milliseconds(400))

        let sandbox: String = try await harness.evaluate(
            "return document.querySelector('iframe[srcdoc]').getAttribute('sandbox')")
        #expect(sandbox == "allow-scripts")
        // The embed's picture is hidden while the live iframe runs over it.
        let pictureHidden: Bool = try await harness.evaluate(
            "const p = document.querySelector('[data-embed-under]');"
                + "return !!p && getComputedStyle(p).visibility === 'hidden'")
        #expect(pictureHidden)
    }

    @Test func hundredRapidShowsEndOnTheLastOne() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        try await harness.load(try Fixture.demo-deckSource())

        var expected = 0
        for press in 0..<100 {
            expected = (press * 7 + 3) % 12
            harness.renderer.show(ShowPosition(slide: expected))
        }
        try await Task.sleep(for: .milliseconds(800)) // Let the last fade finish.
        let layout: [[String: Any]] = try await harness.evaluate(Self.slideLayoutJS)
        let showing = layout.indices.filter { layout[$0]["showing"] as? Bool == true }
        #expect(showing == [expected])
        let frames: Int = try await harness.evaluate("return document.querySelectorAll('iframe[srcdoc]').length")
        let onSlide: Int = try await harness.evaluate(
            Self.embedCountJS(slide: expected))
        #expect(frames == onSlide)
    }

    @Test func thumbnailsNeverStartEmbeds() async throws {
        let harness = RendererHarness(surface: .thumbnail, size: CGSize(width: 320, height: 180))
        defer { harness.close() }
        let source = try Fixture.demo-deckSource()
        try await harness.load(source)
        let liveIndex = source.structure.slides.firstIndex { $0.hasLiveContent }
        let live = try #require(liveIndex)
        try await harness.show(ShowPosition(slide: live), finished: true)
        let frames: Int = try await harness.evaluate("return document.querySelectorAll('iframe').length")
        #expect(frames == 0)
    }
}
