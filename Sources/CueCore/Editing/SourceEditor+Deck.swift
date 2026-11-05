import Foundation

/// Deck-wide edits for redesigns: Cue's override stylesheet, the `<head>`
/// and the whole document. Each is still the smallest patch: only the
/// characters that differ are replaced.
extension SourceEditor {
    /// The deck-wide operations (see `edit(for:)`).
    func deckEdit(for operation: EditOperation) throws -> (SourceEdit, LivePlan) {
        switch operation {
        case .setOverrideStylesheet(let css, let merge):
            return try setOverrideStylesheet(css, merge: merge)
        case .setHeadHTML(let html):
            return (try setHeadHTML(html), .reload)
        case .appendToHead(let markup):
            return (try appendToHead(markup), .reload)
        case .replaceDocument(let html):
            return (minimalEdit(replacing: SourceRange(start: 0, end: text.count), with: html), .reload)
        case .setEmbedHTML(let slide, let embed, let html):
            return (try setEmbedHTML(slide: slide, embed: embed, html: html), .reload)
        case .setTransition(let slide, let kind):
            return (try setTransition(slide: slide, kind: kind), .reload)
        default:
            throw EditError.unsupported("not a deck-wide edit")
        }
    }

    /// The patches turning `range`'s current text into `replacement`.
    func minimalEdit(replacing range: SourceRange, with replacement: String) -> SourceEdit {
        let local = SourceEdit.difference(from: text.slice(range), to: replacement)
        return SourceEdit(local.patches.map { patch in
            SourcePatch(range: SourceRange(start: patch.range.start + range.start, end: patch.range.end + range.start),
                        replacement: patch.replacement)
        })
    }

    func setOverrideStylesheet(_ css: String, merge: Bool) throws -> (SourceEdit, LivePlan) {
        try OverrideCSS.validate(css)
        let block = map.elements.first { $0.tag == "style" && $0.attributes["id"] == Self.overridesID }
        guard let block, let inner = block.innerRange else {
            let body = css.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return (SourceEdit([]), .overrides(created: false)) }
            return (try appendToHead("<style id=\"\(Self.overridesID)\">\(lineEnding)\(body)\(lineEnding)</style>"),
                    .overrides(created: true))
        }
        let current = text.slice(inner)
        let next = merge ? OverrideCSS.merge(css, into: current) : lineEnding + css.trimmingCharacters(in: .whitespacesAndNewlines) + lineEnding
        return (minimalEdit(replacing: inner, with: next), .overrides(created: false))
    }

    func setHeadHTML(_ html: String) throws -> SourceEdit {
        guard let head = map.elements.first(where: { $0.tag == "head" }), let inner = head.innerRange else {
            throw EditError.unsupported("this deck has no <head> written in its file")
        }
        return minimalEdit(replacing: inner, with: html)
    }

    /// Before `</head>`, on its own line; at the start of `<body>` when the
    /// file has no head written out.
    func appendToHead(_ markup: String) throws -> SourceEdit {
        let head = map.elements.first { $0.tag == "head" }
        if let end = head?.endTag?.start {
            let start = text.whitespaceStart(before: end)
            let indent = text.indentation(ofLineAt: end)
            return SourceEdit([.insert(lineEnding + indent + markup, at: start)])
        }
        guard let offset = head?.startTag?.end ?? map.elements.first(where: { $0.tag == "body" })?.startTag?.start else {
            throw EditError.unsupported("this deck has no <head> or <body> to add to")
        }
        return SourceEdit([.insert(markup + lineEnding, at: offset)])
    }
}
