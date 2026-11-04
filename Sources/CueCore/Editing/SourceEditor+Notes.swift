import Foundation

extension SourceEditor {
    /// Speaker notes go where this deck already keeps them: a notes attribute
    /// on the slide, or `<aside class="notes">` (reveal.js), created if missing.
    func setNotes(slide index: Int, to value: String) throws -> (SourceEdit, LivePlan) {
        let slide = try slideElement(index)
        let attributes = Self.notesAttributes(for: structure.adapter)
        if let existing = attributes.first(where: { slide.attributeLocations[$0] != nil }) {
            let edit = SourceEdit(try attributePatches(on: slide, [(existing, value)]))
            return (edit, .attribute(slide.path, name: existing))
        }
        if let aside = notesAside(in: slide) {
            guard let inner = aside.innerRange else { throw EditError.elementHasNoSource }
            let patch = SourcePatch(range: inner, replacement: escaping.text(normalisingNewlines(value)))
            return (SourceEdit([patch]), aside.isLeaf ? .innerHTML(aside.path) : .reload)
        }
        if structure.adapter == .reveal, let endTag = slide.endTag {
            let indent = text.indentation(ofLineAt: endTag.start)
            let aside = "<aside class=\"notes\">\(escaping.text(normalisingNewlines(value)))</aside>"
            return (SourceEdit([.insert("  \(aside)\(lineEnding)\(indent)", at: endTag.start)]), .reload)
        }
        guard let name = attributes.first else { throw EditError.unsupported("notes for this deck format") }
        return (SourceEdit(try attributePatches(on: slide, [(name, value)])), .attribute(slide.path, name: name))
    }

    /// The attributes each format reads notes from, preferred first.
    static func notesAttributes(for adapter: AdapterKind) -> [String] {
        switch adapter {
        case .cue: ["data-cue-notes"]
        case .claudeDesign: ["data-speaker-notes", "data-cue-notes"]
        case .reveal: ["data-notes"]
        case .documentRole: ["data-speaker-notes", "data-notes"]
        case .fallback: ["data-notes", "data-speaker-notes"]
        }
    }

    private func notesAside(in slide: MappedElement) -> MappedElement? {
        map.elements.first { element in
            element.tag == "aside" && element.path.starts(with: slide.path) && element.path != slide.path
                && (element.attributes["class"] ?? "").split(separator: " ").contains("notes")
        }
    }
}
