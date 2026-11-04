import Foundation

extension SourceEditor {
    func addSlide(after index: Int, html: String?) throws -> SourceEdit {
        guard index >= -1, index < structure.slides.count, !structure.slides.isEmpty else {
            throw EditError.slideOutOfRange(index)
        }
        let template = try slideElement(max(index, 0))
        guard let templateRange = template.range else { throw EditError.elementHasNoSource }
        let markup = try html.map { try escaping.verbatim(normalisingNewlines($0)) } ?? blankSlide(like: template)
        let indent = text.indentation(ofLineAt: templateRange.start)
        var patches: [SourcePatch] = index >= 0
            ? [.insert(lineEnding + indent + markup, at: try slideElement(index).range!.end)]
            : [.insert(markup + lineEnding + indent, at: templateRange.start)]
        if let motion = try DeckMotionPatches(editor: self) {
            patches.append(motion.insert(try motion.newEntry(like: max(index, 0)), at: index + 1))
        }
        return SourceEdit(patches)
    }

    func deleteSlide(_ index: Int) throws -> SourceEdit {
        let slide = try slideElement(index)
        guard structure.slides.count > 1 else { throw EditError.lastSlide }
        guard let range = slide.range else { throw EditError.elementHasNoSource }
        let withIndent = SourceRange(start: text.whitespaceStart(before: range.start), end: range.end)
        var patches = [SourcePatch.delete(withIndent)]
        if let motion = try DeckMotionPatches(editor: self), motion.slides.indices.contains(index) {
            patches.append(motion.remove(index))
        }
        return SourceEdit(patches)
    }

    func moveSlide(from: Int, to: Int) throws -> SourceEdit {
        let moving = try slideElement(from)
        let target = try slideElement(to)
        guard from != to else { return SourceEdit([]) }
        guard let range = moving.range, let targetRange = target.range else { throw EditError.elementHasNoSource }
        let leadingStart = text.whitespaceStart(before: range.start)
        let leading = text.slice(SourceRange(start: leadingStart, end: range.start))
        let separator = leading.isEmpty ? lineEnding : leading
        let markup = text.slice(range)
        var patches = [SourcePatch.delete(SourceRange(start: leadingStart, end: range.end))]
        patches.append(to > from
            ? .insert(separator + markup, at: targetRange.end)
            : .insert(markup + separator, at: targetRange.start))
        if let motion = try DeckMotionPatches(editor: self),
           motion.slides.indices.contains(from), motion.slides.indices.contains(to) {
            patches += motion.move(from: from, to: to)
        }
        return SourceEdit(patches)
    }

    /// An empty slide that keeps the deck's wrappers: the slide's start tag
    /// (new id, no label or notes) and each single-child wrapper inside it,
    /// e.g. `section.deck-slide > div.deck-fit > div.deck-scaler > div.slide`.
    func blankSlide(like template: MappedElement) throws -> String {
        guard let startTag = template.startTag else { throw EditError.elementHasNoSource }
        var changes: [(String, String?)] = [("data-label", "New slide")]
        if template.attributes["id"] != nil { changes.append(("id", uniqueSlideID())) }
        for name in Self.notesAttributes(for: structure.adapter) where template.attributes[name] != nil {
            changes.append((name, ""))
        }
        changes.append(("aria-label", nil))
        let relative = try attributePatches(on: template, changes).map { patch in
            let start = patch.range.start - startTag.start
            let range = SourceRange(start: start, end: start + patch.range.length)
            return SourcePatch(range: range, replacement: patch.replacement)
        }
        var markup = try SourceEdit(relative).apply(to: text.slice(startTag)).text
        var closing = "</\(template.tag)>"
        var node = self.node(template.path)
        var path = template.path
        while let current = node, current.children.count == 1, let child = current.children.first,
              let childTag = map.element(at: path + [0])?.startTag {
            markup += text.slice(childTag)
            closing = "</\(child.tag)>" + closing
            node = child
            path += [0]
        }
        return markup + closing
    }

    private func uniqueSlideID() -> String {
        let taken = Set(map.elements.compactMap { $0.attributes["id"] })
        var number = structure.slides.count + 1
        while taken.contains("cue-slide-\(number)") { number += 1 }
        return "cue-slide-\(number)"
    }
}
