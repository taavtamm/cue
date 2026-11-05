import CueCore
import Foundation
import MCP

/// The tools that change the deck. Each becomes one or more `EditOperation`s
/// applied by the host as a single change set.
extension ToolRunner {
    func edit(_ name: String, _ args: ToolArguments) async throws -> CallTool.Result {
        let document = try await document()
        var args = args
        var fetchedFrom: String?
        if name == "insert_image", let address = args.string("url") {
            guard let url = URL(string: address), let host = url.host else { throw CueMCPError.invalid("“url” isn't a web address.") }
            let data = try await self.host.fetchImage(url)
            args = args.setting("source", to: .string("data:\(ImageSniffer.mime(data) ?? "image/png");base64,\(data.base64EncodedString())"))
            fetchedFrom = host
        }
        let facts = DeckDocumentFacts(slideCount: document.structure.slides.count)
        let (operations, slide, fallback) = try plan(name, args, document, facts)
        var summary = args.string("summary") ?? fallback
        if let fetchedFrom { summary += " (image from \(fetchedFrom))" }
        let change = try await host.apply(operations, summary: summary, client: client, slide: slide)
        return try json(ChangeSetReport(change))
    }

    /// The operations for a tool, the slide they're on, and a summary if Claude gave none.
    private func plan(_ name: String, _ args: ToolArguments, _ document: DeckDocument, _ facts: DeckDocumentFacts)
        throws -> ([EditOperation], Int?, String) {
        switch name {
        case "edit_element":
            let path = try ElementTarget.resolve(args.object("target"), in: document)
            return (try elementEdits(path, args, document), slide(containing: path, document), "Edited an element")
        case "replace_slide_html":
            let index = try args.slideIndex(in: facts)
            let html = try ImagePlaceholders.restore(try args.requiredString("html"), from: document.source)
            return ([.replaceSlide(index, html: html)], index, "Replaced slide \(index + 1)")
        case "add_slide":
            let after = try args.requiredInt("after")
            guard (0...facts.slideCount).contains(after) else {
                throw CueMCPError.invalid("“after” must be 0–\(facts.slideCount).")
            }
            let html = try args.string("html").map { try ImagePlaceholders.restore($0, from: document.source) }
            return ([.addSlide(after: after - 1, html: html)], after, "Added a slide after slide \(after)")
        case "delete_slide":
            let index = try args.slideIndex(in: facts)
            return ([.deleteSlide(index)], index, "Deleted slide \(index + 1)")
        case "move_slide":
            let index = try args.slideIndex(in: facts)
            let to = try args.slideIndex("to", in: facts)
            return ([.moveSlide(from: index, to: to)], to, "Moved slide \(index + 1) to \(to + 1)")
        case "set_notes":
            let index = try args.slideIndex(in: facts)
            return ([.setNotes(slide: index, text: try args.requiredString("text"))], index, "Notes on slide \(index + 1)")
        case "set_builds":
            let index = try args.slideIndex(in: facts)
            return ([.setBuilds(slide: index, steps: try builds(args, onSlide: index, document))], index,
                    "Builds on slide \(index + 1)")
        case "move_element":
            let path = try ElementTarget.resolve(args.object("target"), in: document)
            let changes = moveChanges(path, dx: args.double("dx") ?? 0, dy: args.double("dy") ?? 0, document)
            return ([.setStyles(path, changes)], slide(containing: path, document), "Moved an element")
        case "resize_element":
            let path = try ElementTarget.resolve(args.object("target"), in: document)
            guard let width = args.double("width"), let height = args.double("height"), width > 0, height > 0 else {
                throw CueMCPError.invalid("“width” and “height” are required and must be above 0.")
            }
            let changes = [StyleChange("width", "\(Int(width.rounded()))px"), StyleChange("height", "\(Int(height.rounded()))px")]
            return ([.setStyles(path, changes)], slide(containing: path, document), "Resized an element")
        case "delete_element":
            let path = try ElementTarget.resolve(args.object("target"), in: document)
            return ([.deleteElement(path)], slide(containing: path, document), "Deleted an element")
        case "insert_text_box", "insert_image", "insert_shape":
            let index = try args.slideIndex(in: facts)
            return ([.insertElement(slide: index, html: try insertion(name, args, document))], index, "Inserted an element")
        default:
            if let planned = try designPlan(name, args, document, facts) {
                return (planned.operations, planned.slide, planned.summary)
            }
            throw CueMCPError.invalid("Cue has no tool “\(name)”.")
        }
    }

    private func elementEdits(_ path: ElementPath, _ args: ToolArguments, _ document: DeckDocument) throws -> [EditOperation] {
        var operations: [EditOperation] = []
        if let text = args.string("text") { operations.append(.setText(path, text)) }
        if let html = args.string("html") {
            operations.append(.setInnerHTML(path, try ImagePlaceholders.restore(html, from: document.source)))
        }
        for (name, value) in try args.stringMap("attributes") ?? [] {
            operations.append(.setAttribute(path, name: name, value: value))
        }
        if let style = try args.stringMap("style"), !style.isEmpty {
            operations.append(.setStyles(path, style.map { StyleChange($0.0, $0.1) }))
        }
        guard !operations.isEmpty else {
            throw CueMCPError.invalid("edit_element needs at least one of text, html, attributes or style.")
        }
        return operations
    }

    private func builds(_ args: ToolArguments, onSlide slide: Int, _ document: DeckDocument) throws -> [BuildSpec] {
        guard let steps = args.array("steps") else { throw CueMCPError.invalid("“steps” is required (an array).") }
        return try steps.map { step in
            let step = ToolArguments(step.objectValue)
            let targets = try (step.array("targets") ?? []).map {
                try ElementTarget.resolve(ToolArguments($0.objectValue), in: document, defaultSlide: slide)
            }
            guard !targets.isEmpty else { throw CueMCPError.invalid("Each build step needs at least one target.") }
            return BuildSpec(targets: targets, effect: step.string("effect"))
        }
    }

    /// Cue's own elements move by left/top; the deck's by an inline translate.
    private func moveChanges(_ path: ElementPath, dx: Double, dy: Double, _ document: DeckDocument) -> [StyleChange] {
        let element = document.sourceMap.element(at: path)
        let style = element?.attributes["style"] ?? ""
        let start = CGRect(x: 0, y: 0, width: 100, height: 100)
        return ElementPlacement.changes(from: start, to: start.offsetBy(dx: dx, dy: dy), inlineStyle: style,
                                        isCueElement: element?.attributes["data-cue-element"] != nil)
    }

    func slide(containing path: ElementPath, _ document: DeckDocument) -> Int? {
        document.structure.slides.firstIndex { path.starts(with: $0.elementPath) }
    }
}
