import AppKit
import CoreGraphics
import CueCore
import CueRender
import Foundation

/// Moving, resizing, nudging, inserting, duplicating and deleting elements
/// on the slide. Every change is one `EditOperation`, so it undoes in one step.
extension EditorSession {
    // MARK: Dragging

    /// Starts moving or resizing the selection. Nil if there's nothing to drag.
    public func beginDrag(_ kind: ElementDrag.Kind) async -> ElementDrag? {
        guard let selection, let box = selection.inspection?.canvasFrame,
              !structure.slides.contains(where: { $0.elementPath == selection.path }),
              let geometry = await canvasGeometry()
        else { return nil }
        let others = (try? await canvas.snapTargets(
            slide: slide, slideSelector: structure.slideSelector, canvasWidth: structure.canvas.width,
            excluding: selection.cueID
        )) ?? []
        let canvasSize = CGSize(width: structure.canvas.width, height: structure.canvas.height)
        return ElementDrag(kind: kind, element: selection.element, start: box, geometry: geometry,
                           snapping: Snapping(canvas: canvasSize, others: others, threshold: 8 / max(0.01, geometry.scale)))
    }

    /// Shows the drag on the live slide (nothing is written yet).
    public func preview(_ drag: ElementDrag) {
        canvas.previewStyles(cueID: drag.cueID, drag.changes)
    }

    /// Writes the drag as one edit. With `duplicate` (Option-drag), a copy
    /// lands at the new place and the original stays put.
    public func commit(_ drag: ElementDrag, duplicate: Bool) async {
        await canvas.endPreview(cueID: drag.cueID, restore: duplicate || drag.changes.isEmpty)
        guard !drag.changes.isEmpty else { return }
        if duplicate {
            await insertCopy(of: drag.path, at: drag.frame)
        } else {
            await apply(.setStyles(drag.path, drag.changes))
        }
    }

    public func cancel(_ drag: ElementDrag) async {
        await canvas.endPreview(cueID: drag.cueID, restore: true)
    }

    /// Arrow keys: 1 canvas pixel, 10 with Shift. Repeated nudges of the
    /// same element merge into one undo step.
    public func nudge(dx: CGFloat, dy: CGFloat) async {
        guard var drag = await beginDrag(.move) else { return }
        drag.update(delta: CGSize(width: dx, height: dy), shift: false, noSnapping: true)
        await apply(.setStyles(drag.path, drag.changes))
    }

    /// The inspector's X, Y, W and H, in canvas pixels.
    public func setFrame(_ change: (inout CGRect) -> Void) async {
        guard let selection, let start = selection.inspection?.canvasFrame else { return }
        var frame = start
        change(&frame)
        let changes = ElementPlacement.changes(
            from: start, to: frame, inlineStyle: selection.element.attributes["style"] ?? "",
            isCueElement: selection.element.attributes["data-cue-element"] != nil
        )
        if !changes.isEmpty { await apply(.setStyles(selection.path, changes)) }
    }

    /// A point on the surface as a point on the slide's design canvas.
    public func canvasPoint(fromView point: CGPoint) async -> CGPoint? {
        await canvasGeometry()?.canvasPoint(fromView: point)
    }

    public func canvasGeometry() async -> CanvasGeometry? {
        try? await canvas.canvasGeometry(
            slide: slide, slideSelector: structure.slideSelector, canvasWidth: structure.canvas.width
        )
    }

    // MARK: Inserting

    /// Adds a text box, image or shape to the current slide, centred unless
    /// `frame` (canvas pixels) is given, and selects it.
    @discardableResult
    public func insert(_ template: ElementTemplate, frame: CGRect? = nil, imageSize: CGSize? = nil) async -> Bool {
        let canvasSize = CGSize(width: structure.canvas.width, height: structure.canvas.height)
        let place = frame ?? template.defaultFrame(on: canvasSize, imageSize: imageSize)
        let id = ElementTemplate.uniqueID(prefix: "cue", in: document.source)
        guard await apply(.insertElement(slide: slide, html: template.html(id: id, frame: place))) else { return false }
        await selectElement(withID: id)
        return true
    }

    /// An image file, embedded in the deck as a `data:` URI.
    @discardableResult
    public func insertImage(contentsOf url: URL, centredAt point: CGPoint? = nil) async -> Bool {
        let embedder = ImageEmbedder(canvas: CGSize(width: structure.canvas.width, height: structure.canvas.height))
        guard let image = try? await Task.detached { try embedder.embed(contentsOf: url) }.value else {
            lastError = "Cue couldn't read “\(url.lastPathComponent)” as an image."
            return false
        }
        return await insertEmbedded(image, name: url.deletingPathExtension().lastPathComponent, centredAt: point)
    }

    @discardableResult
    public func insertImage(data: Data, centredAt point: CGPoint? = nil) async -> Bool {
        let embedder = ImageEmbedder(canvas: CGSize(width: structure.canvas.width, height: structure.canvas.height))
        guard let image = try? await Task.detached { try embedder.embed(data) }.value else { return false }
        return await insertEmbedded(image, name: "Pasted image", centredAt: point)
    }

    private func insertEmbedded(_ image: ImageEmbedder.Embedded, name: String, centredAt point: CGPoint?) async -> Bool {
        let template = ElementTemplate.image(source: image.dataURI, description: name)
        let canvasSize = CGSize(width: structure.canvas.width, height: structure.canvas.height)
        var frame = template.defaultFrame(on: canvasSize, imageSize: image.pixelSize)
        if let point { frame.origin = CGPoint(x: point.x - frame.width / 2, y: point.y - frame.height / 2) }
        let inserted = await insert(template, frame: frame)
        if inserted, let note = image.note { lastError = note } // Shown as a quiet notice under the slide.
        return inserted
    }

    /// Selects a newly inserted element once the canvas has it.
    func selectElement(withID id: String) async {
        guard let element = document.sourceMap.elements.last(where: { $0.attributes["id"] == id }) else { return }
        await select(cueID: element.cueID)
    }
}
