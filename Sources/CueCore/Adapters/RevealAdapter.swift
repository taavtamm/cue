import Foundation

/// reveal.js decks: `.reveal .slides > section`, vertical stacks as nested
/// sections, `<aside class="notes">`, `.fragment` builds.
///
/// Rendered in passthrough mode: reveal's own script lays out and navigates;
/// the renderer forwards keys and reads the `.present` slide back.
public struct RevealAdapter: DeckAdapter {
    public let kind = AdapterKind.reveal
    public init() {}

    public func detect(_ input: AdapterInput) -> DeckStructure? {
        guard let container = input.root.first(where: { $0.hasClass("reveal") }),
              container.children.contains(where: { $0.hasClass("slides") })
        else { return nil }
        let tops = input.root.slides(matching: ".reveal .slides > section")
        guard !tops.isEmpty else { return nil }

        var slides: [SlideMatch] = []
        var hasStacks = false
        for top in tops {
            let nested = top.node.children.enumerated().filter { $0.element.tag == "section" }
            if nested.isEmpty {
                slides.append(top)
            } else {
                hasStacks = true
                slides += nested.map { SlideMatch(node: $0.element, path: top.path + [$0.offset]) }
            }
        }
        let infos = slides.enumerated().map { index, slide in
            slide.info(index: index, notesAttributes: ["data-notes"], builds: Self.fragments(in: slide.node))
        }
        return DeckStructure(
            adapter: kind,
            renderMode: .passthrough,
            canvas: Self.canvas(input) ?? CanvasSize(width: 960, height: 700),
            slideSelector: hasStacks
                ? ".reveal .slides > section:not(:has(> section)), .reveal .slides > section > section"
                : ".reveal .slides > section",
            slides: infos
        )
    }

    /// One build per distinct `data-fragment-index`, unindexed fragments after, in order.
    static func fragments(in slide: HTMLNode) -> [BuildStep] {
        let fragments = slide.descendants.filter { $0.hasClass("fragment") }
        var indexed: [Int: Int] = [:]
        var steps: [BuildStep] = []
        for fragment in fragments {
            if let raw = fragment["data-fragment-index"], let index = Int(raw) {
                if indexed[index] == nil {
                    indexed[index] = steps.count
                    steps.append(BuildStep(targets: ["[data-fragment-index=\"\(index)\"]"]))
                }
            } else {
                // Reveal steps these in document order; the target is informational
                // because reveal itself drives fragments in passthrough mode.
                steps.append(BuildStep(targets: [".fragment:not([data-fragment-index])"]))
            }
        }
        return steps
    }

    /// `Reveal.initialize({ width: 1280, height: 720 })` in an inline script.
    static func canvas(_ input: AdapterInput) -> CanvasSize? {
        for script in input.root.findAll({ $0.tag == "script" && $0["src"] == nil }) {
            let body = input.innerText(of: script.node)
            guard body.contains("Reveal") else { continue }
            if let width = number(after: "width", in: body), let height = number(after: "height", in: body) {
                return CanvasSize(width: width, height: height)
            }
        }
        return nil
    }

    private static func number(after key: String, in text: String) -> Double? {
        guard let match = text.range(of: key + #"\s*:\s*\d+"#, options: .regularExpression) else { return nil }
        return Double(text[match].filter(\.isNumber))
    }
}
