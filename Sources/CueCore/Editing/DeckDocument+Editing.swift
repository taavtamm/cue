import Foundation

/// Editing a deck: every change is a minimal patch on `source`, followed by a
/// re-parse and a fresh adapter pass. Undo and redo replay inverse patches.
extension DeckDocument {
    @discardableResult
    public mutating func apply(_ operation: EditOperation, at time: Date = Date()) throws -> EditResult {
        let editor = SourceEditor(source: source, root: tree, map: sourceMap, structure: structure, encoding: encoding)
        let (edit, plan) = try editor.edit(for: operation)
        guard !edit.isEmpty else { return .none }
        let before = Snapshot(self)
        let inverse = try replace(with: edit)
        let result = makeResult(edit: edit, plan: plan, before: before)
        history.record(.init(operation: operation, forward: edit, inverse: inverse, plan: plan, time: time))
        return result
    }

    @discardableResult
    public mutating func undo() throws -> EditResult {
        guard let record = history.popUndo() else { throw EditError.nothingToUndo }
        let before = Snapshot(self)
        _ = try replace(with: record.inverse)
        return makeResult(edit: record.inverse, plan: record.plan, before: before)
    }

    @discardableResult
    public mutating func redo() throws -> EditResult {
        guard let record = history.popRedo() else { throw EditError.nothingToRedo }
        let before = Snapshot(self)
        _ = try replace(with: record.forward)
        return makeResult(edit: record.forward, plan: record.plan, before: before)
    }

    /// Resolves a live `data-cue-id` to the element's source.
    public func element(cueID: String) -> MappedElement? { sourceMap.element(cueID: cueID) }

    /// The `[cueID, tag]` list CueBridge tags the live DOM with. The deck's
    /// replaced player script isn't in the served page, so it's left out.
    public var liveManifest: [LiveElement] { sourceMap.liveManifest(excluding: structure.replacedPlayerScript) }

    private mutating func replace(with edit: SourceEdit) throws -> SourceEdit {
        let (text, inverse) = try edit.apply(to: source)
        try replaceSource(text)
        return inverse
    }

    /// Turns the editor's plan into DOM changes using the re-parsed source,
    /// so the live page gets exactly what the new source says.
    private func makeResult(edit: SourceEdit, plan: LivePlan, before: Snapshot) -> EditResult {
        let after = Snapshot(self)
        let structureChanged = before.playback != after.playback
        let remap = before.elementCount != after.elementCount
        let text = SourceText(source)
        var live: LiveUpdate = .reload
        switch plan {
        case .reload:
            break
        case .innerHTML(let path):
            if let element = sourceMap.element(at: path), let inner = element.innerRange {
                live = .inPlace([.setInnerHTML(cueID: element.cueID, html: text.slice(inner))], remap: remap)
            }
        case .attribute(let path, let name):
            if let element = sourceMap.element(at: path) {
                let change = DOMChange.setAttribute(cueID: element.cueID, name: name, value: element.attributes[name])
                live = .inPlace([change], remap: remap)
            }
        case .overrides:
            let block = sourceMap.elements.first {
                $0.tag == "style" && $0.attributes["id"] == SourceEditor.overridesID
            }
            live = .inPlace([.setOverrides(css: block?.innerRange.map(text.slice) ?? "")], remap: remap)
        }
        return EditResult(edit: edit, structureChanged: structureChanged, live: structureChanged ? .reload : live)
    }
}

/// What decides whether open surfaces must reload: how the deck plays.
/// Labels, notes and source offsets change with ordinary edits and don't count.
private struct Snapshot {
    struct Playback: Equatable {
        let adapter: AdapterKind
        let renderMode: RenderMode
        let canvas: CanvasSize
        let selector: String
        let slideIDs: [String]
        let builds: [[BuildStep]]
    }

    let playback: Playback
    let elementCount: Int

    init(_ document: DeckDocument) {
        let structure = document.structure
        playback = Playback(
            adapter: structure.adapter, renderMode: structure.renderMode, canvas: structure.canvas,
            selector: structure.slideSelector, slideIDs: structure.slides.map(\.id),
            builds: structure.slides.map(\.builds)
        )
        elementCount = document.sourceMap.elements.count
    }
}
