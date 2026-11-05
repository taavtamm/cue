import Foundation

/// Turns an `EditOperation` into the smallest `SourceEdit` on the deck's
/// source. It never re-serialises HTML: every patch replaces exactly the
/// characters that change, so the rest of the file stays byte-for-byte.
struct SourceEditor {
    let text: SourceText
    let root: HTMLNode
    let map: SourceMap
    let structure: DeckStructure
    let escaping: HTMLEscaping

    init(source: String, root: HTMLNode, map: SourceMap, structure: DeckStructure, encoding: String.Encoding) {
        text = SourceText(source)
        self.root = root
        self.map = map
        self.structure = structure
        escaping = HTMLEscaping(encoding: encoding)
    }

    var lineEnding: String { text.lineEnding }

    func edit(for operation: EditOperation) throws -> (SourceEdit, LivePlan) {
        switch operation {
        case .setText(let path, let value):
            return (try setText(of: element(path), to: value), .innerHTML(path))
        case .setAttribute(let path, let name, let value):
            let name = name.lowercased()
            return (SourceEdit(try attributePatches(on: element(path), [(name, value)])), .attribute(path, name: name))
        case .setStyle(let path, let property, let value):
            return (try setStyle(on: element(path), property: property, value: value), .attribute(path, name: "style"))
        case .setNotes(let slide, let value):
            return try setNotes(slide: slide, to: value)
        case .addSlide(let after, let html):
            return (try addSlide(after: after, html: html), .reload)
        case .deleteSlide(let index):
            return (try deleteSlide(index), .reload)
        case .moveSlide(let from, let to):
            return (try moveSlide(from: from, to: to), .reload)
        case .setBuilds(let slide, let steps):
            return (try setBuilds(slide: slide, steps: steps), .reload)
        case .setOverride(let selector, let property, let value):
            return try setOverride(selector: selector, property: property, value: value)
        case .setStyles(let path, let changes):
            return (try setStyles(on: element(path), changes), .attribute(path, name: "style"))
        case .insertElement(let slide, let html):
            return try insertElement(onSlide: slide, html: html)
        case .deleteElement(let path):
            return try deleteElement(element(path))
        case .setInnerHTML(let path, let html):
            return (try setInnerHTML(of: element(path), to: html), .innerHTML(path))
        case .replaceSlide(let index, let html):
            return (try replaceSlide(index, with: html), .reload)
        case .patches(let edit):
            return (edit, .reload)
        case .setOverrideStylesheet, .setHeadHTML, .appendToHead, .replaceDocument, .setEmbedHTML, .setTransition:
            return try deckEdit(for: operation)
        }
    }

    // MARK: Finding things

    func element(_ path: ElementPath) throws -> MappedElement {
        guard let element = map.element(at: path) else { throw EditError.elementNotFound }
        guard element.range != nil, element.startTag != nil else { throw EditError.elementHasNoSource }
        return element
    }

    func node(_ path: ElementPath) -> HTMLNode? {
        var node = root
        for index in path {
            guard node.children.indices.contains(index) else { return nil }
            node = node.children[index]
        }
        return node
    }

    func slideElement(_ index: Int) throws -> MappedElement {
        guard structure.slides.indices.contains(index) else { throw EditError.slideOutOfRange(index) }
        return try element(structure.slides[index].elementPath)
    }

    /// Newlines in inserted text follow the file's own line ending.
    func normalisingNewlines(_ value: String) -> String {
        let unified = value.replacingOccurrences(of: "\r\n", with: "\n")
        return lineEnding == "\n" ? unified : unified.replacingOccurrences(of: "\n", with: lineEnding)
    }
}
