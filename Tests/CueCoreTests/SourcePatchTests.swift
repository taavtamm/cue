import Testing
@testable import CueCore

@Suite("Source patches")
struct SourcePatchTests {
    @Test func applyThenInverseRestoresTheText() throws {
        let text = "Hello, 🎉 world"
        let edit = SourceEdit([
            SourcePatch(range: SourceRange(start: 0, end: 5), replacement: "Hi"),
            .insert("!", at: text.utf16.count),
        ])
        let (changed, inverse) = try edit.apply(to: text)
        #expect(changed == "Hi, 🎉 world!")
        #expect(try inverse.apply(to: changed).text == text)
    }

    @Test func offsetsAreUTF16() throws {
        // 🎉 is two UTF-16 units; "world" starts at 10.
        let edit = SourceEdit([SourcePatch(range: SourceRange(start: 10, end: 15), replacement: "Cue")])
        #expect(try edit.apply(to: "Hello, 🎉 world").text == "Hello, 🎉 Cue")
    }

    @Test func overlappingPatchesAreRefused() {
        let edit = SourceEdit([
            SourcePatch(range: SourceRange(start: 0, end: 4), replacement: "a"),
            SourcePatch(range: SourceRange(start: 2, end: 6), replacement: "b"),
        ])
        #expect(throws: EditError.patchOutOfRange) { try edit.apply(to: "0123456789") }
    }

    @Test func insertAndDeleteAtTheSameOffset() throws {
        let edit = SourceEdit([.delete(SourceRange(start: 2, end: 4)), .insert("X", at: 2)])
        let (changed, inverse) = try edit.apply(to: "abcdef")
        #expect(changed == "abXef")
        #expect(try inverse.apply(to: changed).text == "abcdef")
    }
}
