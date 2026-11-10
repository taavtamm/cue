import Foundation
import Testing
@testable import CueCore

@Suite("Heavy-deck warning")
struct SlideLoadReportTests {
    @Test func stillBlursAreFineMovingOnesArent() {
        #expect(!SlideLoad(blurs: 10, loopingAnimations: 0, embeds: 0, redrawsPerSecond: 0).isHeavy,
                "a blur over still content is drawn once")
        let moving = SlideLoad(blurs: 3, loopingAnimations: 1, embeds: 0, redrawsPerSecond: 0)
        #expect(moving.reasons == ["3 blurs over moving content"])
    }

    @Test func eachReasonHasItsThreshold() {
        #expect(!SlideLoad(blurs: 0, loopingAnimations: 5, embeds: 1, redrawsPerSecond: 29).isHeavy)
        let busy = SlideLoad(blurs: 22, loopingAnimations: 19, embeds: 8, redrawsPerSecond: 60)
        #expect(busy.reasons == ["22 blurs over moving content", "19 animations that never stop",
                                 "8 embeds that draw on their own", "scripts redrawing every frame"])
    }

    @Test func theBannerNamesTheWorstSlideAndThePromptListsEveryHeavyOne() {
        let report = DeckLoadReport([
            0: SlideLoad(blurs: 22, loopingAnimations: 19, embeds: 8, redrawsPerSecond: 0),
            3: SlideLoad(blurs: 0, loopingAnimations: 7, embeds: 0, redrawsPerSecond: 0),
            5: SlideLoad(blurs: 0, loopingAnimations: 0, embeds: 0, redrawsPerSecond: 0),
        ])
        #expect(report.isHeavy)
        #expect(report.message == "This deck keeps your GPU busy: slide 1 has 22 blurs over moving content, "
            + "19 animations that never stop and 8 embeds that draw on their own (and 1 more slide).")
        let prompt = report.prompt(deckTitle: "Q3 Review")
        #expect(prompt.contains("“Q3 Review”") && prompt.contains("- Slide 4: 7 animations that never stop"))
        #expect(!prompt.contains("Slide 6"), "light slides aren't listed")
        #expect(prompt.contains("get_performance") && prompt.contains("render_slide"))
    }

    @Test func aLightDeckHasNoReport() {
        #expect(!DeckLoadReport([0: SlideLoad(blurs: 1, loopingAnimations: 1, embeds: 0, redrawsPerSecond: 0)]).isHeavy)
    }

    @Test func neverIsRememberedInTheSidecar() throws {
        var sidecar = CueSidecar()
        sidecar.hidesPerformanceWarning = true
        let data = try JSONEncoder().encode(sidecar)
        #expect(try JSONDecoder().decode(CueSidecar.self, from: data).hidesPerformanceWarning)
        #expect(try JSONDecoder().decode(CueSidecar.self, from: Data("{}".utf8)).hidesPerformanceWarning == false)
    }
}
