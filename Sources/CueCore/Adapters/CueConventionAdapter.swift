import Foundation

/// Cue's own convention:
///   `<section data-cue-slide data-cue-notes="…">` marks a slide,
///   `data-cue-build="n"` on a child reveals it at build n (1-based),
///   `data-cue-effect="rise"` names the build effect,
///   `<meta name="cue:canvas" content="1920x1080">` sets the design size.
public struct CueConventionAdapter: DeckAdapter {
    public let kind = AdapterKind.cue
    public init() {}

    public func detect(_ input: AdapterInput) -> DeckStructure? {
        let slides = input.root.slides(where: { $0["data-cue-slide"] != nil })
        guard !slides.isEmpty else { return nil }
        let infos = slides.enumerated().map { index, slide in
            slide.info(index: index, notesAttributes: ["data-cue-notes"], builds: Self.builds(in: slide.node))
        }
        return DeckStructure(
            adapter: kind,
            renderMode: .cueDriven,
            canvas: CanvasParsing.cueCanvas(input.root) ?? .hd,
            slideSelector: "[data-cue-slide]",
            slides: infos
        )
    }

    /// Groups `data-cue-build` children by step number, in ascending order.
    static func builds(in slide: HTMLNode) -> [BuildStep] {
        var steps: [Int: [HTMLNode]] = [:]
        for node in slide.descendants {
            guard let raw = node["data-cue-build"], let step = Int(raw.trimmed), step > 0 else { continue }
            steps[step, default: []].append(node)
        }
        return steps.keys.sorted().map { step in
            let effect = steps[step]?.compactMap { $0["data-cue-effect"] }.first
            return BuildStep(targets: ["[data-cue-build=\"\(step)\"]"], effect: effect)
        }
    }
}
