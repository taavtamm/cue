import Foundation
import Testing
@testable import CueCore

@Suite struct ShowPaceTests {
    @Test func halfwayAtHalfTimeIsOnPace() {
        let pace = ShowPace(elapsed: 750, target: 1500, progress: 0.5)
        #expect(pace.status == .onPace)
        #expect(pace.text == "on pace")
    }

    @Test func slowProgressIsBehind() {
        let pace = ShowPace(elapsed: 900, target: 1500, progress: 0.4) // scheduled 600 s
        #expect(pace.status == .behind(300))
        #expect(pace.text == "5 min behind")
    }

    @Test func fastProgressIsAhead() {
        #expect(ShowPace(elapsed: 300, target: 1500, progress: 0.5).text == "8 min ahead")
    }

    @Test func pastTheTargetIsOvertime() {
        #expect(ShowPace(elapsed: 1620, target: 1500, progress: 0.9).text == "2 min over")
    }

    @Test func progressCountsBuildsWithinASlide() {
        let counts = [1, 4, 1, 1]
        #expect(ShowPace.progress(of: ShowPosition(slide: 0), stateCounts: counts) == 0)
        #expect(ShowPace.progress(of: ShowPosition(slide: 1, build: 2), stateCounts: counts) == 0.375)
        #expect(ShowPace.progress(of: ShowPosition(slide: 3), stateCounts: counts) == 0.75)
    }

    @Test func defaultTargetIsTwoMinutesASlideRoundedToFive() {
        #expect(ShowPace.defaultTarget(slideCount: 12) == 25 * 60)
        #expect(ShowPace.defaultTarget(slideCount: 1) == 5 * 60)
        #expect(ShowPace.defaultTarget(slideCount: 12, rehearsed: [60, 90]) == 150)
    }

    @Test func sidecarWithoutNewKeysStillLoads() throws {
        let json = Data(#"{"version":1,"allowedHosts":["fonts.gstatic.com"]}"#.utf8)
        let sidecar = try JSONDecoder().decode(CueSidecar.self, from: json)
        #expect(sidecar.targetDuration == nil)
        #expect(sidecar.displayRoles.isEmpty)
    }

    @Test func sidecarSitsBesideTheDeck() {
        let url = CueSidecar.url(forDeck: URL(filePath: "/talks/demo-deck.html"))
        #expect(url.path == "/talks/demo-deck.cue.json")
    }
}
