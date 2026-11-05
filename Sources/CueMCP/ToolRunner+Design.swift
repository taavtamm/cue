import CueCore
import Foundation
import MCP

/// Deck-wide tools for redesigns: the design system, Cue's override
/// stylesheet, theme variables, fonts, the `<head>`, the whole document,
/// live embeds, transitions and a contact sheet of every slide.
extension ToolRunner {
    /// Read-only design tools; nil when `name` isn't one.
    func design(_ name: String, _ args: ToolArguments) async throws -> CallTool.Result? {
        switch name {
        case "get_styles":
            let document = try await document()
            if args.string("selector") != nil || args.string("query") != nil {
                let rules = DeckStyleSummary.rules(in: document, selector: args.string("selector"), query: args.string("query"))
                return try json(rules)
            }
            return try json(DeckStyleSummary(document))
        case "get_deck_html":
            return text(Self.capped(BlockPlaceholders.shortenAll(try await document().source)))
        case "get_head":
            let document = try await document()
            guard let inner = document.sourceMap.elements.first(where: { $0.tag == "head" })?.innerRange else {
                return text("This deck has no <head> written in its file.")
            }
            return text(Self.capped(BlockPlaceholders.shortenAll(Self.slice(document.source, inner))))
        case "get_embeds":
            let document = try await document()
            let index = try args.slideIndex(in: DeckDocumentFacts(slideCount: document.structure.slides.count))
            let embeds = document.embeds(onSlide: index).map {
                DeckEmbed(id: $0.id, html: Self.capped(ImagePlaceholders.shorten($0.html)))
            }
            let report = EmbedsReport(slide: index + 1, transition: document.transition(ofSlide: index), embeds: embeds)
            return try json(report)
        case "render_deck":
            return try await renderDeck(args)
        default:
            return nil
        }
    }

    /// The operations a write tool runs, the slide they're on, and a summary.
    typealias Plan = (operations: [EditOperation], slide: Int?, summary: String)

    /// Write design tools; nil when `name` isn't one.
    func designPlan(_ name: String, _ args: ToolArguments, _ document: DeckDocument, _ facts: DeckDocumentFacts)
        throws -> Plan? {
        if let plan = try stylePlan(name, args, document) { return plan }
        switch name {
        case "edit_embed":
            let index = try args.slideIndex(in: facts)
            let html = try ImagePlaceholders.restore(try args.requiredString("html"), from: document.source)
            return ([.setEmbedHTML(slide: index, embed: try args.requiredString("embed"), html: html)], index,
                    "Changed a live embed on slide \(index + 1)")
        case "set_transition":
            let index = try args.slideIndex(in: facts)
            let kind = try args.requiredString("kind")
            guard ["none", "fade", "push", "magic"].contains(kind) else {
                throw CueMCPError.invalid("“kind” is none, fade, push or magic.")
            }
            return ([.setTransition(slide: index, kind: kind == "none" ? nil : kind)], index,
                    "Transition after slide \(index + 1): \(kind)")
        default:
            return nil
        }
    }

    /// Deck-wide looks and the document itself.
    private func stylePlan(_ name: String, _ args: ToolArguments, _ document: DeckDocument) throws -> Plan? {
        switch name {
        case "set_deck_style":
            let mode = args.string("mode") ?? "merge"
            guard ["merge", "replace"].contains(mode) else { throw CueMCPError.invalid("“mode” is merge or replace.") }
            let css = try ImagePlaceholders.restore(try args.requiredString("css"), from: document.source)
            return ([.setOverrideStylesheet(css: css, merge: mode == "merge")], nil, "Deck style")
        case "set_theme_variables":
            let variables = try args.stringMap("variables") ?? []
            guard !variables.isEmpty, variables.allSatisfy({ $0.0.hasPrefix("--") }) else {
                throw CueMCPError.invalid("“variables” maps custom properties (starting with --) to values, "
                    + "e.g. {\"--accent\": \"#2f7bff\"}.")
            }
            return (variables.map { .setOverride(selector: ":root", property: $0.0, value: $0.1) }, nil, "Theme variables")
        case "add_font":
            return ([.appendToHead(try Self.fontLink(args))], nil, "Added the font \(try args.requiredString("family"))")
        case "replace_deck_html":
            let html = try BlockPlaceholders.restoreAll(try args.requiredString("html"), from: document.source)
            var check = document
            try check.replaceSource(html)
            // Any page reads as one whole-page slide; a deck that had slides losing them is a mistake.
            let lostSlides = check.structure.slideSelector == "body" && document.structure.slideSelector != "body"
            guard !check.structure.slides.isEmpty, !lostSlides else {
                throw CueMCPError.invalid("That HTML has no slides Cue can find. Keep the deck's slide elements "
                    + "(\(document.structure.slideSelector)) or use <section data-cue-slide> for each slide.")
            }
            return ([.replaceDocument(html)], nil, "Redesigned the deck")
        case "set_head_html":
            let html = try BlockPlaceholders.restoreAll(try args.requiredString("html"), from: document.source)
            return ([.setHeadHTML(html)], nil, "Changed the deck's head")
        default:
            return nil
        }
    }

    private func renderDeck(_ args: ToolArguments) async throws -> CallTool.Result {
        let document = try await document()
        let count = document.structure.slides.count
        var numbers = (args.array("slides") ?? []).compactMap { $0.intValue }
        if numbers.isEmpty { numbers = Array(1...max(1, count)) }
        guard numbers.allSatisfy({ (1...count).contains($0) }) else {
            throw CueMCPError.invalid("Slides are 1–\(count).")
        }
        numbers = Array(numbers.prefix(24))
        var renders: [(number: Int, png: Data)] = []
        for number in numbers { renders.append((number, try await host.renderSlide(number - 1, build: nil))) }
        let canvas = CGSize(width: document.structure.canvas.width, height: document.structure.canvas.height)
        let columns = args.int("columns") ?? (numbers.count <= 4 ? 2 : numbers.count <= 9 ? 3 : 4)
        let png = try ContactSheet.compose(renders, columns: columns, canvas: canvas)
        return CallTool.Result(content: [.image(data: png.base64EncodedString(), mimeType: "image/png", metadata: nil)])
    }

    // MARK: Helpers

    static func fontLink(_ args: ToolArguments) throws -> String {
        let family = try args.requiredString("family").trimmingCharacters(in: .whitespaces)
        guard !family.isEmpty, family.allSatisfy({ $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }) else {
            throw CueMCPError.invalid("“family” is a Google Fonts family name, like Inter or Playfair Display.")
        }
        let weights = (args.array("weights") ?? []).compactMap { $0.intValue }.filter { (100...900).contains($0) }.sorted()
        let name = family.replacingOccurrences(of: " ", with: "+")
        let axis = weights.isEmpty ? "" : ":wght@" + weights.map(String.init).joined(separator: ";")
        let href = "https://fonts.googleapis.com/css2?family=\(name)\(axis)&amp;display=swap"
        return "<link rel=\"stylesheet\" href=\"\(href)\">"
    }

    static func capped(_ text: String, limit: Int = 300_000) -> String {
        text.count <= limit ? text : String(text.prefix(limit)) + "\n<!-- … cut at \(limit) characters. -->"
    }

    static func slice(_ source: String, _ range: SourceRange) -> String {
        (source as NSString).substring(with: NSRange(location: range.start, length: range.length))
    }
}

/// A slide's embeds and transition, for `get_embeds`.
struct EmbedsReport: Encodable {
    let slide: Int
    let transition: String?
    let embeds: [DeckEmbed]
}
