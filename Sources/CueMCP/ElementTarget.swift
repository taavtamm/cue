import CueCore
import Foundation

/// Which element a tool works on. Claude can name it three ways:
/// - `cue_id`: the live id from `get_selection`.
/// - `path`: child-element indices from `<html>`, also from `get_selection`.
/// - `slide` + `selector`: a CSS selector (tag, #id, .class, [attr], descendants)
///   within that slide, plus `index` when several match (0-based).
enum ElementTarget {
    static func resolve(_ target: ToolArguments?, in document: DeckDocument, defaultSlide: Int? = nil) throws -> ElementPath {
        guard let target else { throw CueMCPError.invalid("“target” is required: give cue_id, path, or slide + selector.") }
        if let cueID = target.string("cue_id") {
            guard let element = document.element(cueID: cueID) else {
                throw CueMCPError.invalid("No element has cue_id \(cueID) now. Call get_selection or get_slide_html again.")
            }
            return element.path
        }
        if let path = target.array("path")?.compactMap(\.intValue), !path.isEmpty {
            guard document.sourceMap.element(at: path) != nil else {
                throw CueMCPError.invalid("No element at path \(path). The deck may have changed; call get_selection again.")
            }
            return path
        }
        guard let selector = target.string("selector") else {
            throw CueMCPError.invalid("“target” needs cue_id, path, or slide + selector.")
        }
        let facts = DeckDocumentFacts(slideCount: document.structure.slides.count)
        let slide = target.int("slide") != nil ? try target.slideIndex(in: facts) : defaultSlide
        guard let slide else { throw CueMCPError.invalid("A selector target needs “slide” (1-based).") }
        return try match(selector, onSlide: slide, index: target.int("index"), in: document)
    }

    static func match(_ selector: String, onSlide slide: Int, index: Int?, in document: DeckDocument) throws -> ElementPath {
        guard let parsed = SimpleSelector(selector) else {
            throw CueMCPError.invalid("“\(selector)” isn't a selector Cue understands (tag, #id, .class, [attr], descendants).")
        }
        let slidePath = document.structure.slides[slide].elementPath
        guard let slideNode = node(at: slidePath, in: document.tree) else {
            throw CueMCPError.invalid("Slide \(slide + 1) has no source element.")
        }
        let matches = parsed.matches(in: slideNode).map { slidePath + $0.path }
        guard !matches.isEmpty else { throw CueMCPError.invalid("Nothing on slide \(slide + 1) matches “\(selector)”.") }
        if let index {
            guard matches.indices.contains(index) else {
                throw CueMCPError.invalid("“\(selector)” matches \(matches.count) elements on slide \(slide + 1); index \(index) is out of range.")
            }
            return matches[index]
        }
        guard matches.count == 1 else {
            throw CueMCPError.invalid("“\(selector)” matches \(matches.count) elements on slide \(slide + 1). Add “index” (0-based) or a narrower selector.")
        }
        return matches[0]
    }

    static func node(at path: ElementPath, in root: HTMLNode) -> HTMLNode? {
        var node = root
        for index in path {
            guard node.children.indices.contains(index) else { return nil }
            node = node.children[index]
        }
        return node
    }
}
