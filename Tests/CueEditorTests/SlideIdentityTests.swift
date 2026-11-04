import CueCore
import Testing
@testable import CueEditor

@Suite("Slide identity")
struct SlideIdentityTests {
    private func slides(_ ids: [String]) -> [SlideInfo] {
        ids.map { SlideInfo(id: $0, label: $0, elementPath: []) }
    }

    @Test func repeatedIDsGetSuffixes() {
        #expect(SlideIdentity.ids(slides(["a", "b", "a", "a"])) == ["a", "b", "a#2", "a#3"])
    }

    @Test func firstDifferenceFindsTheRestoredSlide() {
        let before = ["1", "2", "4", "5"]
        let after = ["1", "2", "3", "4", "5"] // Undoing the delete of slide 3.
        #expect(SlideIdentity.firstDifference(before: before, after: after) == 2)
        #expect(SlideIdentity.firstDifference(before: after, after: after) == nil)
        #expect(SlideIdentity.firstDifference(before: ["1", "2"], after: ["1", "2", "3"]) == 2)
    }

    @Test func mappingFollowsMovedSlides() {
        let mapping = SlideIdentity.mapping(before: ["a", "b", "c"], after: ["b", "c", "a"])
        #expect(mapping == [0: 2, 1: 0, 2: 1])
        #expect(SlideIdentity.mapping(before: ["a", "b"], after: ["b"]) == [1: 0])
    }
}
