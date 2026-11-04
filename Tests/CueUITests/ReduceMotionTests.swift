import Foundation
import SwiftUI
import Testing
@testable import CueUI

@Suite("Reduce Motion")
@MainActor
struct ReduceMotionTests {
    @Test func caretNeverBlinksWithReduceMotion() {
        let idle = CaretBlinkPolicy.presentation(
            isFocused: true, hasRangedSelection: false, secondsSinceEdit: nil, reduceMotion: true)
        #expect(idle == .solid)
    }

    @Test func overlayHoldsCaretSolidWithReduceMotion() {
        let overlay = CaretOverlayView(frame: .zero)
        overlay.reduceMotion = { true }
        overlay.setFocused(true)
        #expect(overlay.presentation == .solid)
        #expect(overlay.caret.animation(forKey: "blink") == nil)
    }

    @Test func overlayBlinksWithoutReduceMotion() {
        let overlay = CaretOverlayView(frame: .zero)
        overlay.reduceMotion = { false }
        overlay.setFocused(true)
        #expect(overlay.presentation == .blinking)
        #expect(overlay.caret.animation(forKey: "blink") != nil)
    }

    @Test func glowStopsRotatingWithReduceMotion() {
        let date = Date(timeIntervalSinceReferenceDate: 1.25)
        #expect(SiriGlow<Capsule>.angle(at: date, reduceMotion: true) == .zero)
        #expect(SiriGlow<Capsule>.angle(at: date, reduceMotion: false) == .degrees(90))
    }
}
