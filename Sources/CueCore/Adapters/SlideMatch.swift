import Foundation

/// A slide element found in the tree, with its path from `<html>`.
struct SlideMatch {
    let node: HTMLNode
    let path: ElementPath

    /// Builds a `SlideInfo` with the shared heuristics; adapters override fields.
    func info(index: Int, notesAttributes: [String], builds: [BuildStep] = [], live: Bool? = nil) -> SlideInfo {
        SlideInfo(
            id: SlideFacts.id(for: node, index: index),
            label: SlideFacts.label(for: node, index: index),
            notes: SlideFacts.notes(for: node, attributes: notesAttributes),
            elementPath: path,
            sourceRange: node.range,
            builds: builds,
            hasLiveContent: live ?? SlideFacts.hasLiveContent(node)
        )
    }
}

extension HTMLNode {
    func slides(matching selector: String) -> [SlideMatch] {
        guard let parsed = SimpleSelector(selector) else { return [] }
        return parsed.matches(in: self).map { SlideMatch(node: $0.node, path: $0.path) }
    }

    func slides(where match: (HTMLNode) -> Bool) -> [SlideMatch] {
        findAll(match).map { SlideMatch(node: $0.node, path: $0.path) }
    }
}
