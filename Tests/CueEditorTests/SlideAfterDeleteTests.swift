import Testing
@testable import CueEditor

@Suite("Slide after delete")
struct SlideAfterDeleteTests {
    @Test func deletingAboveKeepsTheSameSlideInView() {
        // Viewing slide 5 (index 4) of 10, delete slide 2: slide 5 is now index 3.
        #expect(SlideAfterDelete.index(deleting: 1, current: 4, countBefore: 10) == 3)
    }

    @Test func deletingBelowStaysPut() {
        #expect(SlideAfterDelete.index(deleting: 7, current: 4, countBefore: 10) == 4)
    }

    @Test func deletingTheCurrentShowsTheNextOne() {
        #expect(SlideAfterDelete.index(deleting: 4, current: 4, countBefore: 10) == 4)
    }

    @Test func deletingTheLastShowsTheNewLast() {
        #expect(SlideAfterDelete.index(deleting: 9, current: 9, countBefore: 10) == 8)
    }

    @Test func deletingTheOnlySlideStaysAtZero() {
        #expect(SlideAfterDelete.index(deleting: 0, current: 0, countBefore: 1) == 0)
    }
}
