import Foundation

/// Heuristics shared by adapters: labels, notes and live-content detection.
enum SlideFacts {
    /// `data-label`, then a meaningful `aria-label`, then the first heading.
    static func label(for slide: HTMLNode, index: Int) -> String {
        if let label = slide["data-label"]?.trimmed, !label.isEmpty { return label }
        if let aria = slide["aria-label"]?.trimmed, !aria.isEmpty, !isPositionNoise(aria) { return aria }
        let headings = ["h1", "h2", "h3"]
        for tag in headings {
            if let heading = slide.first(where: { $0.tag == tag }), !heading.text.isEmpty {
                return heading.text
            }
        }
        return "Slide \(index + 1)"
    }

    /// Notes from an attribute, else from `<aside class="notes">`.
    static func notes(for slide: HTMLNode, attributes: [String]) -> String {
        for name in attributes {
            if let notes = slide[name]?.trimmed, !notes.isEmpty { return notes }
        }
        return slide.first { $0.tag == "aside" && $0.hasClass("notes") }?.text ?? ""
    }

    private static let liveTags: Set<String> = ["iframe", "video", "canvas", "embed", "object", "audio"]

    static func hasLiveContent(_ slide: HTMLNode) -> Bool {
        slide.first { node in
            liveTags.contains(node.tag) || node["data-embed"] != nil || node["data-live"] != nil
        } != nil
    }

    /// "Slide 3 of 12" and similar carry no title.
    private static func isPositionNoise(_ text: String) -> Bool {
        let pattern = #"^(slide|page)\s*\d+(\s*(of|/)\s*\d+)?$"#
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func id(for slide: HTMLNode, index: Int) -> String {
        if let id = slide["id"], !id.isEmpty { return id }
        return "slide-\(index + 1)"
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
