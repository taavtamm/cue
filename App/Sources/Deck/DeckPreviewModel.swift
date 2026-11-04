import CueCore
import Observation

/// What the temporary deck window shows: which slide is previewed, and
/// facts about the deck for the summary line.
@MainActor @Observable
final class DeckPreviewModel {
    let title: String
    let structure: DeckStructure
    private(set) var slide = 0
    private(set) var liveSlides: Set<Int> = []

    init(document: DeckDocument) {
        structure = document.structure
        let label = document.fileURL.deletingPathExtension().lastPathComponent
        title = label.isEmpty ? "Untitled" : label
        liveSlides = Set(document.structure.slides.indices.filter { document.structure.slides[$0].hasLiveContent })
    }

    var slideCount: Int { structure.slides.count }
    var currentLabel: String { structure.slides.indices.contains(slide) ? structure.slides[slide].label : "" }

    var summary: String {
        let size = "\(Int(structure.canvas.width)) × \(Int(structure.canvas.height))"
        let count = slideCount == 1 ? "1 slide" : "\(slideCount) slides"
        return "HTML · \(size) · \(count) · \(Self.describe(structure.adapter, structure.renderMode))"
    }

    func select(_ slide: Int) {
        self.slide = min(max(0, slide), max(0, slideCount - 1))
    }

    func noteLive(_ slides: [Int]) {
        liveSlides.formUnion(slides)
    }

    private static func describe(_ adapter: AdapterKind, _ mode: RenderMode) -> String {
        let name = switch adapter {
        case .cue: "Cue deck"
        case .claudeDesign: "Claude Design"
        case .reveal: "reveal.js"
        case .documentRole: "HTML slides"
        case .fallback: "Web page"
        }
        return mode == .passthrough ? "\(name) · deck's own player" : name
    }
}
