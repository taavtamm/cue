import Foundation

/// The last resort, so every HTML file opens:
/// 1. Marp exports (`div.marpit` sections),
/// 2. top-level `<section>` elements,
/// 3. the whole page as one slide.
public struct FallbackAdapter: DeckAdapter {
    public let kind = AdapterKind.fallback
    public init() {}

    public func detect(_ input: AdapterInput) -> DeckStructure? {
        marp(input) ?? topLevelSections(input) ?? Self.wholePage(input)
    }

    /// Marp's bespoke template ships its own navigation script; when present we
    /// let it run (passthrough). A script-free export is driven by Cue.
    private func marp(_ input: AdapterInput) -> DeckStructure? {
        guard let marpit = input.root.first(where: { $0.hasClass("marpit") }) else { return nil }
        let slides = input.root.slides(matching: ".marpit section")
        guard !slides.isEmpty else { return nil }
        let svg = marpit.first { $0.tag == "svg" }
        let hasScript = input.root.first { $0.tag == "script" && $0["src"] == nil } != nil
        return DeckStructure(
            adapter: kind,
            renderMode: hasScript ? .passthrough : .cueDriven,
            canvas: CanvasParsing.viewBox(svg?["viewBox"]) ?? CanvasSize(width: 1280, height: 720),
            slideSelector: ".marpit section",
            slides: infos(slides)
        )
    }

    /// `<section>` elements that aren't inside another section.
    private func topLevelSections(_ input: AdapterInput) -> DeckStructure? {
        var slides: [SlideMatch] = []
        func walk(_ node: HTMLNode, _ path: ElementPath) {
            for (index, child) in node.children.enumerated() {
                if child.tag == "section" {
                    slides.append(SlideMatch(node: child, path: path + [index]))
                } else {
                    walk(child, path + [index])
                }
            }
        }
        walk(input.root, [])
        guard !slides.isEmpty else { return nil }
        return DeckStructure(
            adapter: kind,
            renderMode: .cueDriven,
            canvas: CanvasParsing.cueCanvas(input.root) ?? .hd,
            slideSelector: "section:not(section section)",
            slides: infos(slides)
        )
    }

    /// An ordinary web page: shown as-is at window size, scrolling allowed.
    /// Passthrough, because forcing an unknown layout into a 16:9 box crops it.
    static func wholePage(_ input: AdapterInput) -> DeckStructure {
        let body = input.root.body ?? input.root
        let bodyIndex = input.root.children.firstIndex { $0 === body }
        let title = input.root.head?.children.first { $0.tag == "title" }?.text ?? ""
        let slide = SlideInfo(
            id: "page",
            label: title.isEmpty ? SlideFacts.label(for: body, index: 0) : title,
            notes: SlideFacts.notes(for: body, attributes: []),
            elementPath: bodyIndex.map { [$0] } ?? [],
            sourceRange: body.range,
            hasLiveContent: SlideFacts.hasLiveContent(body)
        )
        return DeckStructure(
            adapter: .fallback,
            renderMode: .passthrough,
            canvas: CanvasParsing.cueCanvas(input.root) ?? .hd,
            slideSelector: "body",
            slides: [slide]
        )
    }

    private func infos(_ slides: [SlideMatch]) -> [SlideInfo] {
        slides.enumerated().map { $1.info(index: $0, notesAttributes: ["data-notes", "data-speaker-notes"]) }
    }
}
