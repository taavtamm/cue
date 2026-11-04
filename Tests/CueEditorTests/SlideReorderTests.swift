import Testing
@testable import CueEditor

@Suite("Slide reorder")
struct SlideReorderTests {
    @Test func upperHalfMeansAbove() {
        #expect(SlideReorder.gap(overSlide: 3, pointerY: 10, rowHeight: 120) == 3)
        #expect(SlideReorder.gap(overSlide: 3, pointerY: 90, rowHeight: 120) == 4)
    }

    @Test func droppingNextToItselfDoesNothing() {
        #expect(SlideReorder.destination(moving: 2, toGap: 2) == nil)
        #expect(SlideReorder.destination(moving: 2, toGap: 3) == nil)
    }

    @Test func droppingFurtherMovesIt() {
        #expect(SlideReorder.destination(moving: 2, toGap: 0) == 0)
        #expect(SlideReorder.destination(moving: 0, toGap: 5) == 4) // Below slide 5 of 5+.
        #expect(SlideReorder.destination(moving: 4, toGap: 2) == 2)
    }

    @Test func keyboardStepsStopAtTheEnds() {
        #expect(SlideReorder.step(0, by: -1, count: 5) == nil)
        #expect(SlideReorder.step(4, by: 1, count: 5) == nil)
        #expect(SlideReorder.step(2, by: 1, count: 5) == 3)
    }
}
