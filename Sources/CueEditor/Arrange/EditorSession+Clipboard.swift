import AppKit
import CoreGraphics
import CueCore
import Foundation

/// Duplicate, delete, stacking order, and copy and paste of elements.
extension EditorSession {
    /// Cue's own pasteboard type: the element's markup, ready to place.
    public static let elementPasteboardType = NSPasteboard.PasteboardType("app.cue.element")

    public func duplicateSelection() async {
        guard let selection, let frame = selection.inspection?.canvasFrame else { return }
        await insertCopy(of: selection.path, at: frame.offsetBy(dx: 24, dy: 24))
    }

    public func deleteSelection() async {
        guard let selection else { return }
        endInteractions()
        if await apply(.deleteElement(selection.path)) { self.selection = nil }
    }

    /// Bring forward (+1) or send backward (-1), by inline `z-index`.
    public func restack(by step: Int) async {
        guard let selection, let style = selection.inspection?.computedStyle else { return }
        let current = Int(style["z-index"] ?? "") ?? 0
        var changes = [StyleChange("z-index", String(current + step))]
        if style["position"] == "static" { changes.append(StyleChange("position", "relative")) }
        await apply(.setStyles(selection.path, changes))
    }

    public func copySelection() {
        guard let selection, let frame = selection.inspection?.canvasFrame,
              let markup = portableMarkup(of: selection.path, at: frame, id: "cue-copy") else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markup, forType: Self.elementPasteboardType)
        pasteboard.setString(markup, forType: .html)
        pasteboard.setString(document.tree.node(at: selection.path)?.text ?? "", forType: .string)
    }

    /// Pastes a copied element, an image, or plain text as a new text box.
    public func paste() async {
        let pasteboard = NSPasteboard.general
        if let markup = pasteboard.string(forType: Self.elementPasteboardType) {
            let id = ElementTemplate.uniqueID(prefix: "cue", in: document.source)
            let html = markup.replacingOccurrences(of: "id=\"cue-copy\"", with: "id=\"\(id)\"")
            if await apply(.insertElement(slide: slide, html: html)) { await selectElement(withID: id) }
        } else if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            await insertImage(data: data)
        } else if let text = pasteboard.string(forType: .string), !text.isEmpty {
            await insert(.textBox(text: text, fontSize: 48, fontFamily: nil))
        }
    }

    func insertCopy(of path: ElementPath, at frame: CGRect) async {
        let id = ElementTemplate.uniqueID(prefix: "cue", in: document.source)
        guard let markup = portableMarkup(of: path, at: frame, id: id) else { return }
        if await apply(.insertElement(slide: slide, html: markup)) { await selectElement(withID: id) }
    }

    private func portableMarkup(of path: ElementPath, at frame: CGRect, id: String) -> String? {
        guard let range = document.sourceMap.element(at: path)?.range else { return nil }
        let html = (document.source as NSString).substring(with: NSRange(location: range.start, length: range.length))
        return ElementCopy.portable(html, frame: frame, newID: id)
    }
}
