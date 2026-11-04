import Foundation
import Testing
@testable import CueCore

/// A clock the test moves by hand.
final class ManualClock: @unchecked Sendable {
    var time: TimeInterval = 100
    var clock: ShowClock { ShowClock { self.time } }
}

@MainActor @Suite("ShowController")
struct ShowControllerTests {
    /// Slide 0: no builds. Slide 1: two builds. Slide 2: none.
    func makeShow(_ clock: ManualClock = ManualClock()) -> ShowController {
        ShowController(stateCounts: [1, 3, 1], clock: clock.clock)
    }

    @Test func nextStepsThroughBuildsThenSlides() {
        let show = makeShow()
        var seen: [ShowPosition] = [show.position]
        for _ in 0..<6 {
            show.next()
            seen.append(show.position)
        }
        #expect(seen.map { [$0.slide, $0.build] } == [[0, 0], [1, 0], [1, 1], [1, 2], [2, 0], [2, 0], [2, 0]])
        #expect(show.isOnLastState)
    }

    @Test func previousLandsOnPriorSlidesFinalBuild() {
        let show = makeShow()
        show.jump(toSlide: 2)
        show.previous()
        #expect(show.position == ShowPosition(slide: 1, build: 2))
        show.previous()
        show.previous()
        show.previous()
        #expect(show.position == ShowPosition(slide: 0, build: 0))
        show.previous()
        #expect(show.position == .start)
    }

    @Test func numberThenReturnJumps() {
        let show = makeShow()
        show.handle(.digit(3))
        #expect(show.typedNumber == 3)
        show.handle(.confirm)
        #expect(show.position == ShowPosition(slide: 2))
        show.handle(.digit(9))
        show.handle(.digit(9))
        show.handle(.confirm)
        #expect(show.position.slide == 2, "clamped to the last slide")
        show.handle(.digit(1))
        show.handle(.next)
        #expect(show.typedNumber == nil, "any other key cancels the typed number")
    }

    @Test func blackAndWhiteScreensClearOnNavigation() {
        let show = makeShow()
        show.handle(.toggleBlack)
        #expect(show.isBlack)
        show.handle(.toggleWhite)
        #expect(show.isWhite && !show.isBlack)
        show.handle(.next)
        #expect(!show.isWhite && !show.isBlack)
        show.handle(.toggleBlack)
        show.handle(.toggleBlack)
        #expect(!show.isBlack)
    }

    @Test func timerStartsOnFirstAdvanceAndPauses() {
        let clock = ManualClock()
        let show = makeShow(clock)
        clock.time += 5
        #expect(show.elapsed == 0)
        show.next()
        clock.time += 10
        #expect(show.elapsed == 10)
        show.toggleTimer()
        clock.time += 30
        #expect(show.elapsed == 10)
        show.toggleTimer()
        clock.time += 2
        #expect(show.elapsed == 12)
    }

    @Test func escapeRequestsEnd() {
        let show = makeShow()
        show.handle(.endShow)
        #expect(show.endRequested)
    }

    @Test func hundredRapidPressesStayConsistent() {
        let show = ShowController(stateCounts: Array(repeating: 2, count: 12), clock: ManualClock().clock)
        var generator = SeededGenerator(seed: 42)
        var expectedIndex = 0  // flattened state index over 24 states
        for _ in 0..<100 {
            if Bool.random(using: &generator) {
                show.handle(.next)
                expectedIndex = min(expectedIndex + 1, 23)
            } else {
                show.handle(.previous)
                expectedIndex = max(expectedIndex - 1, 0)
            }
            #expect(show.position.build <= show.finalBuild(of: show.position.slide))
        }
        #expect(show.position == ShowPosition(slide: expectedIndex / 2, build: expectedIndex % 2))
    }

    @Test func followAndUpdateClampPositions() {
        let show = makeShow()
        show.follow(ShowPosition(slide: 9, build: 9))
        #expect(show.position == ShowPosition(slide: 2, build: 0))
        show.jump(toSlide: 1, build: 2)
        show.update(stateCounts: [1, 1])
        #expect(show.position == ShowPosition(slide: 1, build: 0))
    }

    @Test func standardKeyMapCoversClickers() {
        let map = ShowKeyMap.standard
        #expect(map.action(for: ShowKeyMap.Name.pageDown) == .next)
        #expect(map.action(for: ShowKeyMap.Name.pageUp) == .previous)
        #expect(map.action(for: " ") == .next)
        #expect(map.action(for: "b") == .toggleBlack)
        #expect(map.action(for: "7") == .digit(7))
        #expect(map.action(for: ShowKeyMap.Name.escape) == .endShow)
    }
}

/// Deterministic randomness for repeatable tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
