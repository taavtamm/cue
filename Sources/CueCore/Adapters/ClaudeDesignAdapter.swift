import Foundation

/// Decks exported by Claude Design: `hz:*` meta tags, `section.deck-slide`
/// with `data-label` and `data-speaker-notes`, builds and embeds in a
/// `#deck-motion` JSON block, and one inline player script.
///
/// Cue replaces that player script (in memory only) with its universal player,
/// which reads the same JSON, so one controller owns the show on every screen.
public struct ClaudeDesignAdapter: DeckAdapter {
    public let kind = AdapterKind.claudeDesign
    public init() {}

    /// The labelled slide container. `hz:slide-selector` (".slide" in real
    /// exports) names the fixed-size canvas *inside* each container, which has
    /// no id, label or notes, so the container wins when present.
    static let containerSelector = ".deck-slide"
    static let otherSelectors = ["[data-document-role=\"page\"]", "[aria-roledescription=\"slide\"]"]

    public func detect(_ input: AdapterInput) -> DeckStructure? {
        let root = input.root
        let declared = root.meta(named: "hz:slide-selector")
        let motionNode = Self.motionScript(in: root)
        guard declared != nil || CanvasParsing.hzCanvas(root) != nil || motionNode != nil else { return nil }

        let candidates = [Self.containerSelector] + [declared].compactMap { $0 } + Self.otherSelectors
        guard let (selector, slides) = Self.firstMatching(candidates, in: root) else { return nil }

        let motion = motionNode.flatMap { Self.decodeMotion(input.innerText(of: $0)) }
        let infos = slides.enumerated().map { index, slide in
            slide.info(
                index: index,
                notesAttributes: ["data-speaker-notes", "data-cue-notes"],
                builds: motion?.builds(forSlide: index) ?? [],
                live: motion?.hasEmbeds(slide: index)
            )
        }
        return DeckStructure(
            adapter: kind,
            renderMode: .cueDriven,
            canvas: CanvasParsing.hzCanvas(root) ?? .hd,
            slideSelector: selector,
            slides: infos,
            replacedPlayerScript: Self.playerScript(in: input)?.range
        )
    }

    static func firstMatching(_ selectors: [String], in root: HTMLNode) -> (String, [SlideMatch])? {
        for selector in selectors {
            let slides = root.slides(matching: selector)
            if !slides.isEmpty { return (selector, slides) }
        }
        return nil
    }

    static func motionScript(in root: HTMLNode) -> HTMLNode? {
        root.first { $0.tag == "script" && $0["id"] == "deck-motion" }
    }

    static func decodeMotion(_ json: String) -> DeckMotion? {
        try? JSONDecoder().decode(DeckMotion.self, from: Data(json.utf8))
    }

    /// The inline classic script that reads `#deck-motion`: the deck's player.
    static func playerScript(in input: AdapterInput) -> HTMLNode? {
        input.root.first { node in
            guard node.tag == "script", node["src"] == nil, node["id"] != "deck-motion" else { return false }
            let type = node["type"]?.lowercased() ?? ""
            guard type.isEmpty || type.contains("javascript") || type == "module" else { return false }
            return input.innerText(of: node).contains("deck-motion")
        }
    }
}
