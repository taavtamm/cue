import Testing
@testable import CueUI

@Suite("Caret blink policy")
struct CaretBlinkPolicyTests {
    @Test func cycleIsAboutOnePointOneSeconds() {
        #expect(CaretBlinkPolicy.period == 1.1)
    }

    @Test func fadesTakeAboutOneHundredFiftyMilliseconds() {
        #expect((0.14...0.16).contains(CaretBlinkPolicy.fadeDuration))
    }

    @Test func holdsOnThenFadesOutThenHoldsOffThenFadesIn() {
        let opacity = CaretBlinkPolicy.opacity(atCycleTime:)
        #expect(opacity(0) == 1)
        #expect(opacity(0.40) == 1)            // hold on
        #expect(abs(opacity(0.495) - 0.5) < 0.05) // midway through the fade out
        #expect(opacity(0.7) == 0)             // hold off
        #expect(opacity(1.05) > 0.5)           // fading back in (starts at 0.946 s)
        #expect(opacity(1.1) == 1)             // next cycle starts on
    }

    @Test func fadeUsesEaseInOut() {
        // Ease-in-out moves slowly at the ends: a quarter of the way in,
        // the caret has lost much less than a quarter of its opacity.
        let quarter = 0.418 + 0.25 * CaretBlinkPolicy.fadeDuration
        #expect(CaretBlinkPolicy.opacity(atCycleTime: quarter) > 0.85)
    }

    @Test func solidWhileTypingAndForHalfASecondAfter() {
        let typing = CaretBlinkPolicy.presentation(
            isFocused: true, hasRangedSelection: false, secondsSinceEdit: 0.2, reduceMotion: false)
        let later = CaretBlinkPolicy.presentation(
            isFocused: true, hasRangedSelection: false, secondsSinceEdit: 0.6, reduceMotion: false)
        #expect(typing == .solid)
        #expect(later == .blinking)
    }

    @Test func hiddenForRangedSelectionOrWithoutFocus() {
        #expect(CaretBlinkPolicy.presentation(
            isFocused: true, hasRangedSelection: true, secondsSinceEdit: nil, reduceMotion: false) == .hidden)
        #expect(CaretBlinkPolicy.presentation(
            isFocused: false, hasRangedSelection: false, secondsSinceEdit: nil, reduceMotion: false) == .hidden)
    }
}
