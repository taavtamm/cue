import AppKit
import CueCore
import Foundation
import Testing
@testable import CueRender

/// Milestone 2: every surface follows one ShowController.
@Suite("Stage, presenter and preview stay in step", .serialized)
@MainActor
struct SyncTests {
    static let currentJS = "const c = window.__cue.debug().current; return c ? [c.slide, c.build] : [-1, -1]"

    /// A deck with builds, so the test covers build steps as well as slides.
    static let buildDeck = """
        <html><body>
        <section data-cue-slide><h1>One</h1></section>
        <section data-cue-slide><h1>Two</h1><p data-cue-build="1">A</p><p data-cue-build="2">B</p></section>
        <section data-cue-slide><h1>Three</h1><p data-cue-build="1">C</p></section>
        <section data-cue-slide><h1>Four</h1></section>
        </body></html>
        """

    @Test func demo-deckSurfacesAgreeAfter100RapidPresses() async throws {
        try await runRapidPresses(source: try Fixture.demo-deckSource(), presses: 100, seed: 7)
    }

    @Test func buildDeckSurfacesAgreeAfter100RapidPresses() async throws {
        try await runRapidPresses(source: try Fixture.deck(html: Self.buildDeck), presses: 100, seed: 11)
    }

    @Test func previewShowsTheNextBuildThenTheNextSlideFinished() {
        let counts = [1, 3, 1]
        let midSlide = ShowBroadcaster.preview(after: ShowPosition(slide: 1, build: 0), stateCounts: counts)
        #expect(midSlide?.position == ShowPosition(slide: 1, build: 1))
        #expect(midSlide?.finished == false)
        let lastBuild = ShowBroadcaster.preview(after: ShowPosition(slide: 1, build: 2), stateCounts: counts)
        #expect(lastBuild?.position == ShowPosition(slide: 2))
        #expect(lastBuild?.finished == true)
        #expect(ShowBroadcaster.preview(after: ShowPosition(slide: 2), stateCounts: counts) == nil)
    }

    @Test func mirrorAnimationsAreLinedUpWithTheStage() async throws {
        let deck = """
            <html><head><style>@keyframes spin { to { transform: rotate(360deg) } }
            .spinner { width: 40px; height: 40px; background: red; animation: spin 10s linear infinite }</style></head>
            <body><section data-cue-slide><div class="spinner"></div><div class="spinner"></div></section></body></html>
            """
        let stage = RendererHarness(surface: .stage)
        let mirror = RendererHarness(surface: .mirror)
        defer { stage.close(); mirror.close() }
        try await stage.load(try Fixture.deck(html: deck))
        try await mirror.load(try Fixture.deck(html: deck))
        // Test windows aren't visible to WebKit, so their animations don't advance on
        // their own. Put the two pages at different points in the animation instead.
        let _: Any? = try await stage.renderer.evaluateInBridge(
            "document.getAnimations().forEach((a, i) => { a.currentTime = 4000 + i * 1000 }); return null")
        #expect(try await times(mirror) == [0, 0])

        let broadcaster = ShowBroadcaster(stateCounts: [1])
        broadcaster.add(stage.renderer)
        broadcaster.add(mirror.renderer)
        await broadcaster.alignNow()

        try await mirror.waitUntilAsync("mirror aligned") {
            guard let mirrored = try? await self.times(mirror), mirrored.count == 2 else { return false }
            return abs(mirrored[0] - 4000) < 100 && abs(mirrored[1] - 5000) < 100
        }
    }

    @Test func alignmentIsSkippedWhenTheSlidesDiffer() async throws {
        let one = "<html><style>@keyframes f{to{opacity:0}}.a{animation:f 9s infinite}</style>"
            + "<body><section data-cue-slide><p class=a>x</p></section></body></html>"
        let two = one.replacingOccurrences(of: "<p class=a>x</p>", with: "<p class=a>x</p><p class=a>y</p>")
        let stage = RendererHarness(surface: .stage)
        let mirror = RendererHarness(surface: .mirror)
        defer { stage.close(); mirror.close() }
        try await stage.load(try Fixture.deck(html: one))
        try await mirror.load(try Fixture.deck(html: two))
        let applied: Bool = try await mirror.evaluate(
            "return window.__cue.timeAnchor.apply({ wall: Date.now(), times: [3000] })")
        #expect(!applied)
    }

    private func times(_ harness: RendererHarness) async throws -> [Double] {
        try await harness.evaluate("return document.getAnimations().map(a => a.currentTime)")
    }

    // MARK: Helpers

    private func runRapidPresses(source: DeckSource, presses: Int, seed: UInt64) async throws {
        let stage = RendererHarness(surface: .stage)
        let presenter = RendererHarness(surface: .presenterCurrent, size: CGSize(width: 1000, height: 562))
        let next = RendererHarness(surface: .nextPreview, size: CGSize(width: 440, height: 248))
        defer { [stage, presenter, next].forEach { $0.close() } }
        try await stage.load(source)
        try await presenter.load(source)
        try await next.load(source)

        let controller = ShowController(structure: source.structure)
        let broadcaster = ShowBroadcaster(stateCounts: controller.stateCounts)
        [stage, presenter, next].forEach { broadcaster.add($0.renderer) }

        var random = SeededRandom(seed: seed)
        for burst in 0..<(presses / 10) {
            for _ in 0..<10 { // Ten presses with no waiting in between, like a clicker held down.
                if random.next() % 4 == 0 { controller.previous() } else { controller.next() }
                broadcaster.broadcast(controller.position)
            }
            try await expectInStep(stage: stage, presenter: presenter, next: next, controller: controller, burst: burst)
            if controller.isOnLastState { controller.jump(toSlide: 0) }
        }
    }

    private func expectInStep(
        stage: RendererHarness, presenter: RendererHarness, next: RendererHarness,
        controller: ShowController, burst: Int
    ) async throws {
        let expected = [controller.position.slide, controller.position.build]
        let preview = ShowBroadcaster.preview(after: controller.position, stateCounts: controller.stateCounts)
        try await stage.waitUntilAsync("surfaces converge after burst \(burst)") {
            let onStage: [Int]? = try? await stage.evaluate(Self.currentJS)
            let onPresenter: [Int]? = try? await presenter.evaluate(Self.currentJS)
            return onStage == expected && onPresenter == expected
        }
        if let preview {
            let previewState: [Int] = try await next.evaluate(Self.currentJS)
            let slide = preview.position.slide
            let finalBuild = preview.finished ? controller.finalBuild(of: slide) : preview.position.build
            #expect(previewState == [preview.position.slide, finalBuild], "Next preview after burst \(burst)")
        }
    }
}

/// Small deterministic generator so failures replay exactly.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state >> 33
    }
}
