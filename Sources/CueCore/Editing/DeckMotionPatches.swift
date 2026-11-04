import Foundation

/// Minimal patches to a Claude Design deck's `#deck-motion` JSON. The deck's
/// player looks slides up there by index, so adding, removing or moving a
/// slide must do the same to `slides[]`, and nothing else in the block.
struct DeckMotionPatches {
    let spans: JSONSpans
    /// Where the JSON text starts in the deck's source.
    let base: Int
    let slides: [Range<Int>]
    /// The whole `slides` array, brackets included.
    private let slidesArray: Range<Int>

    init?(editor: SourceEditor) throws {
        guard editor.structure.adapter == .claudeDesign,
              let script = editor.map.elements.first(where: Self.isMotionScript),
              let inner = script.innerRange
        else { return nil }
        spans = JSONSpans(editor.text.slice(inner))
        base = inner.start
        slidesArray = try spans.range(at: [.field("slides")])
        slides = try spans.elements(at: [.field("slides")])
    }

    private static func isMotionScript(_ element: MappedElement) -> Bool {
        element.tag == "script" && element.attributes["id"] == "deck-motion"
    }

    /// An entry for a new slide: one state, no builds or embeds, the
    /// transition and background of `template`.
    func newEntry(like template: Int?) throws -> String {
        var transition = "\"fade\""
        var background = "\"#ffffff\""
        if let template, slides.indices.contains(template) {
            transition = (try? spans.text(spans.range(at: [.field("slides"), .index(template), .field("transition")])))
                ?? transition
            background = (try? spans.text(spans.range(at: [.field("slides"), .index(template), .field("bg")])))
                ?? background
        }
        return "{\"transition\":\(transition),\"bg\":\(background),"
            + "\"steps\":[{\"hidden\":[],\"events\":[],\"auto\":false}],\"embeds\":[]}"
    }

    func insert(_ entry: String, at index: Int) -> SourcePatch {
        if slides.indices.contains(index) { return .insert(entry + ",", at: base + slides[index].lowerBound) }
        if let last = slides.last { return .insert("," + entry, at: base + last.upperBound) }
        return .insert(entry, at: base + slidesArray.lowerBound + 1)
    }

    func remove(_ index: Int) -> SourcePatch {
        let element = slides[index]
        if index + 1 < slides.count { return .delete(range(element.lowerBound, slides[index + 1].lowerBound)) }
        if index > 0 { return .delete(range(slides[index - 1].upperBound, element.upperBound)) }
        return .delete(range(element.lowerBound, element.upperBound))
    }

    /// Moves `slides[from]` so it ends up at index `to`.
    func move(from: Int, to: Int) -> [SourcePatch] {
        let entry = spans.text(slides[from])
        if to > from {
            return [.delete(range(slides[from].lowerBound, slides[from + 1].lowerBound)),
                    .insert("," + entry, at: base + slides[to].upperBound)]
        }
        return [.insert(entry + ",", at: base + slides[to].lowerBound),
                .delete(range(slides[from - 1].upperBound, slides[from].upperBound))]
    }

    func replaceSteps(ofSlide index: Int, with json: String) throws -> SourcePatch {
        let steps = try spans.range(at: [.field("slides"), .index(index), .field("steps")])
        return SourcePatch(range: range(steps.lowerBound, steps.upperBound), replacement: json)
    }

    private func range(_ start: Int, _ end: Int) -> SourceRange {
        SourceRange(start: base + start, end: base + end)
    }
}
