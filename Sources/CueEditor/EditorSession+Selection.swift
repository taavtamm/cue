import CoreGraphics
import CueCore
import CueRender
import Foundation

/// Clicking on the slide: single click selects, double-click edits text or
/// lets a live embed take clicks, ⌘-click always selects.
extension EditorSession {
    /// Selects the source element under a point on the canvas.
    @discardableResult
    public func click(at point: CGPoint) async -> EditorSelection? {
        endInteractions()
        guard let hit = try? await canvas.element(at: point) else {
            selection = nil
            return nil
        }
        return await select(cueID: hit.cueID)
    }

    /// Double-click: a live embed starts taking clicks; a text element starts
    /// inline editing; anything else just selects.
    public func doubleClick(at point: CGPoint) async {
        if let embed = try? await canvas.liveEmbed(at: point) {
            selection = nil
            interactiveEmbed = embed
            try? await canvas.setEmbedsInteractive(true)
            return
        }
        guard let selected = await click(at: point) else { return }
        if selected.inspection?.isLeaf == true { await beginInlineEdit() }
    }

    @discardableResult
    public func select(cueID: String) async -> EditorSelection? {
        guard let element = document.element(cueID: cueID) else {
            selection = nil
            return nil
        }
        selection = makeSelection(for: element)
        await refreshSelection()
        return selection
    }

    public func clearSelection() {
        endInteractions()
        selection = nil
    }

    /// Ends embed interaction and inline editing (committing typed text).
    public func endInteractions() {
        if interactiveEmbed != nil {
            interactiveEmbed = nil
            Task { try? await canvas.setEmbedsInteractive(false) }
        }
        if inlineEdit != nil { Task { try? await canvas.endTextEditing(commit: true) } }
    }

    /// Re-reads the selection's box and style from the page, after an edit,
    /// a reload or a resize. Follows the element by its source path.
    public func refreshSelection() async {
        guard let current = selection else { return }
        guard let element = document.sourceMap.element(at: current.path) else {
            selection = nil
            return
        }
        var next = makeSelection(for: element)
        let inspection = try? await canvas.inspect(
            cueID: element.cueID, slideSelector: structure.slideSelector,
            canvasWidth: structure.canvas.width, buildTargets: buildTargets(of: slide)
        )
        next.inspection = inspection
        if let inspection {
            let color = try? await canvas.styleSource(cueID: element.cueID, property: "color")
            let font = try? await canvas.styleSource(cueID: element.cueID, property: "font-size")
            next.values = InspectorValues(inspection: inspection, colorSource: color ?? nil, fontSource: font ?? nil)
            next.kind = ElementKind(tag: element.tag, hasEmbed: inspection.hostsEmbed, isLeaf: inspection.isLeaf)
        }
        guard selection?.path == current.path else { return } // The user selected something else meanwhile.
        selection = next
    }

    /// The label on the selection box: "h1 · Build 1 · fade up".
    public var selectionLabel: String? {
        guard let selection else { return nil }
        var parts = [selection.element.tag]
        let builds = currentSlide?.builds ?? []
        if let step = selection.inspection?.buildStep, builds.indices.contains(step) {
            parts.append("Build \(step + 1)")
            if let effect = builds[step].effect { parts.append(effect) }
        }
        return parts.joined(separator: " · ")
    }

    /// The slide's build steps as selectors, for the page to match against.
    func buildTargets(of index: Int) -> [[String]] {
        guard structure.slides.indices.contains(index) else { return [] }
        return structure.slides[index].builds.map(\.targets)
    }

    private func makeSelection(for element: MappedElement) -> EditorSelection {
        var selection = EditorSelection(element: element)
        let slidePath = currentSlide?.elementPath
        selection.breadcrumb = Breadcrumb.items(for: element.path, slidePath: slidePath, in: document.sourceMap)
        let node = document.tree.node(at: element.path)
        let label = element.attributes["data-label"] ?? element.attributes["aria-label"] ?? node?.text ?? ""
        selection.name = label.count > 40 ? String(label.prefix(39)) + "…" : label
        return selection
    }
}
