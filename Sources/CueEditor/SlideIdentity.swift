import CueCore

/// Stable identities for the deck's slides across edits, so the sidebar can
/// animate moves and deletes, thumbnails can follow their slides, and undo
/// can show the slide it brought back.
public enum SlideIdentity {
    /// One unique id per slide: the slide's own id, with `#2`, `#3`… for
    /// repeats (a duplicated slide keeps its original's id in the HTML).
    public static func ids(_ slides: [SlideInfo]) -> [String] {
        var seen: [String: Int] = [:]
        return slides.map { slide in
            let count = (seen[slide.id] ?? 0) + 1
            seen[slide.id] = count
            return count == 1 ? slide.id : "\(slide.id)#\(count)"
        }
    }

    /// The first position where the two orders differ (a slide added,
    /// removed or moved there), or nil when they're the same.
    public static func firstDifference(before: [String], after: [String]) -> Int? {
        if let index = zip(before, after).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset {
            return index
        }
        return before.count == after.count ? nil : min(before.count, after.count)
    }

    /// Where each slide went: old index → new index, for slides in both.
    public static func mapping(before: [String], after: [String]) -> [Int: Int] {
        let newIndex = Dictionary(after.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        var result: [Int: Int] = [:]
        for (old, id) in before.enumerated() {
            if let new = newIndex[id] { result[old] = new }
        }
        return result
    }
}
