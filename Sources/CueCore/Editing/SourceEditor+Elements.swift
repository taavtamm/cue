import Foundation

extension SourceEditor {
    /// Replaces a leaf element's content with escaped text.
    func setText(of element: MappedElement, to value: String) throws -> SourceEdit {
        if MappedElement.voidTags.contains(element.tag) { throw EditError.voidElement(element.tag) }
        if MappedElement.rawTextTags.contains(element.tag) { throw EditError.rawTextElement(element.tag) }
        guard element.isLeaf else { throw EditError.notALeaf }
        guard let inner = element.innerRange else { throw EditError.elementHasNoSource }
        return SourceEdit([SourcePatch(range: inner, replacement: escaping.text(normalisingNewlines(value)))])
    }

    /// Sets or removes several attributes on one element. New attributes go
    /// together at the end of the start tag, in the order given.
    func attributePatches(
        on element: MappedElement, _ changes: [(name: String, value: String?)]
    ) throws -> [SourcePatch] {
        guard let startTag = element.startTag else { throw EditError.elementHasNoSource }
        var patches: [SourcePatch] = []
        var added = ""
        for (name, value) in changes {
            guard HTMLEscaping.isValidAttributeName(name), !Self.reservedAttributes.contains(name) else {
                throw EditError.invalidAttributeName(name)
            }
            let value = value.map(normalisingNewlines)
            if let location = element.attributeLocations[name] {
                patches.append(replacing(location, name: name, with: value))
            } else if let value {
                added += " \(name)=\"\(escaping.attribute(value))\""
            }
        }
        if !added.isEmpty {
            let offset = insertionPoint(inStartTag: startTag)
            let precededBySpace = text.unit(at: offset - 1)?.isWhitespace == true
            patches.append(.insert(precededBySpace ? String(added.dropFirst()) + " " : added, at: offset))
        }
        return patches
    }

    private func replacing(_ location: AttributeLocation, name: String, with value: String?) -> SourcePatch {
        guard let value else {
            let start = text.whitespaceStart(before: location.range.start)
            return .delete(SourceRange(start: start, end: location.range.end))
        }
        if let valueRange = location.valueRange, let quote = location.quote {
            return SourcePatch(range: valueRange, replacement: escaping.attribute(value, quote: quote))
        }
        // Bare or unquoted: rewrite this one attribute, quoted.
        return SourcePatch(range: location.range, replacement: "\(name)=\"\(escaping.attribute(value))\"")
    }

    /// Cue's live-page markers. They must never be written to the file.
    static let reservedAttributes: Set<String> = ["data-cue-id", "data-cue-owned"]

    /// Just before `>` or `/>` of a start tag, and before any space ahead of it.
    func insertionPoint(inStartTag startTag: SourceRange) -> Int {
        var offset = startTag.end - 1 // the `>`
        if text.unit(at: offset - 1) == "/" { offset -= 1 }
        return offset == text.whitespaceStart(before: offset) ? offset : text.whitespaceStart(before: offset)
    }

    /// Sets one property inside the `style` attribute, keeping the rest as written.
    func setStyle(on element: MappedElement, property: String, value: String?) throws -> SourceEdit {
        let property = property.trimmingCharacters(in: .whitespaces).lowercased()
        guard StyleDeclarations.isValidProperty(property) else { throw EditError.invalidStyleProperty(property) }
        if let value, value.contains(where: { ";{}\n\r".contains($0) }) {
            throw EditError.invalidStyleProperty("\(property): \(value)")
        }
        let value = value?.trimmingCharacters(in: .whitespaces)
        guard let location = element.attributeLocations["style"], let valueRange = location.valueRange,
              let quote = location.quote
        else {
            let current = element.attributes["style"] ?? ""
            let declarations = StyleDeclarations(current)
            let patched = try SourceEdit(declarations.sourcePatches(setting: property, to: value, base: 0))
                .apply(to: current).text
            let newValue = patched.isEmpty && value == nil ? nil : patched
            return SourceEdit(try attributePatches(on: element, [("style", newValue)]))
        }
        let declarations = StyleDeclarations(text.slice(valueRange))
        let escapedValue = value.map { escaping.attribute($0, quote: quote) }
        return SourceEdit(declarations.sourcePatches(setting: property, to: escapedValue, base: valueRange.start))
    }
}
