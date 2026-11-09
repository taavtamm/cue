import Foundation

/// Editing elements on a slide by hand: moving and resizing (several style
/// properties at once), inserting and deleting elements, and formatted text.
extension SourceEditor {
    /// Sets several properties of the inline style in one patch over the
    /// style attribute's value. One patch (rather than one per property)
    /// lets consecutive moves of the same element merge into one undo step.
    func setStyles(on element: MappedElement, _ changes: [StyleChange]) throws -> SourceEdit {
        for change in changes {
            let property = change.property.lowercased()
            guard StyleDeclarations.isValidProperty(property) else { throw EditError.invalidStyleProperty(property) }
            if let value = change.value, value.contains(where: { ";{}\n\r".contains($0) }) {
                throw EditError.invalidStyleProperty("\(property): \(value)")
            }
        }
        let location = element.attributeLocations["style"]
        let quote = location?.quote ?? "\""
        var current = location?.valueRange.map(text.slice) ?? ""
        for change in changes {
            let value = change.value.map { escaping.attribute($0.trimmingCharacters(in: .whitespaces), quote: quote) }
            current = try SourceEdit(StyleDeclarations(current).sourcePatches(
                setting: change.property.lowercased(), to: value, base: 0
            )).apply(to: current).text
        }
        if let location, let valueRange = location.valueRange, location.quote != nil {
            return SourceEdit([SourcePatch(range: valueRange, replacement: current)])
        }
        // No quoted style attribute yet: add one (or rewrite a bare one).
        let unescaped = current // Already escaped for a double-quoted attribute.
        if let location {
            return SourceEdit([SourcePatch(range: location.range, replacement: "style=\"\(unescaped)\"")])
        }
        guard let startTag = element.startTag else { throw EditError.elementHasNoSource }
        let offset = insertionPoint(of: element, startTag: startTag)
        let precededBySpace = text.unit(at: offset - 1)?.isWhitespace == true
        let attribute = "style=\"\(unescaped)\""
        return SourceEdit([.insert(precededBySpace ? attribute + " " : " " + attribute, at: offset)])
    }

    /// Appends markup inside the slide's design canvas, on its own line.
    func insertElement(onSlide index: Int, html: String) throws -> (SourceEdit, LivePlan) {
        let container = try canvasContainer(ofSlide: index)
        guard let endTag = container.endTag, let startTag = container.startTag else {
            throw EditError.elementHasNoSource
        }
        let markup = escaping.markup(normalisingNewlines(html.trimmingCharacters(in: .whitespacesAndNewlines)))
        let offset = text.whitespaceStart(before: endTag.start)
        let indent = text.indentation(ofLineAt: startTag.start) + "  "
        let patch = SourcePatch.insert(lineEnding + indent + markup, at: offset)
        return (SourceEdit([patch]), .inserted(parent: container.path))
    }

    /// Removes an element and the whitespace that led up to it.
    func deleteElement(_ element: MappedElement) throws -> (SourceEdit, LivePlan) {
        guard let range = element.range else { throw EditError.elementHasNoSource }
        if structure.slides.contains(where: { $0.elementPath == element.path }) {
            throw EditError.unsupported("Use Delete Slide to remove a whole slide.")
        }
        let start = text.whitespaceStart(before: range.start)
        return (SourceEdit([.delete(SourceRange(start: start, end: range.end))]), .removed(cueID: element.cueID))
    }

    /// Replaces an element's content with sanitised formatted text.
    func setInnerHTML(of element: MappedElement, to html: String) throws -> SourceEdit {
        if MappedElement.voidTags.contains(element.tag) { throw EditError.voidElement(element.tag) }
        if MappedElement.rawTextTags.contains(element.tag) { throw EditError.rawTextElement(element.tag) }
        guard let inner = element.innerRange else { throw EditError.elementHasNoSource }
        // HTML formatting inside SVG or MathML breaks out of it when parsed, damaging the drawing.
        let ancestors = (0...element.path.count).compactMap { map.element(at: Array(element.path.prefix($0))) }
        if ancestors.contains(where: { ["svg", "math"].contains($0.tag) }) {
            throw EditError.unsupported("Formatted text can't go inside a drawing (\(element.tag)).")
        }
        let clean = RichTextSanitizer.sanitize(normalisingNewlines(html))
        return SourceEdit([SourcePatch(range: inner, replacement: escaping.markup(clean))])
    }

    /// The element that holds a slide's own boxes: the slide, or the last of
    /// its single-child wrapper `div`s (e.g. `.deck-fit > .deck-scaler > .slide`).
    func canvasContainer(ofSlide index: Int) throws -> MappedElement {
        var current = try slideElement(index)
        while let node = node(current.path), node.children.count == 1,
              ["div", "section", "main", "article"].contains(node.children[0].tag),
              let child = map.element(at: current.path + [0]), child.range != nil {
            current = child
        }
        return current
    }
}
