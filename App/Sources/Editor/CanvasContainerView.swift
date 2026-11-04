import AppKit
import CueEditor
import CueUI
import WebKit

/// Holds the editor's slide surface, the selection overlay and the glowing
/// caret. Decides who gets each click: the overlay selects; while editing
/// text or trying out an embed, clicks inside it go to the page.
final class CanvasContainerView: NSView {
    private let session: EditorSession
    private let overlay: SelectionOverlayView
    private let caret = CaretOverlayView()
    private var inlineEdit: InlineEditState?
    private var interactiveEmbed: CGRect?
    private var lastInputCount = 0
    private var resizeRefresh: Task<Void, Never>?

    init(session: EditorSession) {
        self.session = session
        overlay = SelectionOverlayView(session: session)
        super.init(frame: .zero)
        for view in [session.canvas, overlay, caret] as [NSView] {
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        caret.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("CanvasContainerView is created in code") }

    override func layout() {
        super.layout()
        for view in [session.canvas, overlay, caret] as [NSView] { view.frame = bounds }
        resizeRefresh?.cancel()
        resizeRefresh = Task { [session] in // The selection box follows the slide as it scales.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await session.refreshSelection()
        }
    }

    func update(selection: CGRect?, label: String?, inlineEdit: InlineEditState?, interactiveEmbed: CGRect?) {
        let startedEditing = self.inlineEdit == nil && inlineEdit != nil
        self.inlineEdit = inlineEdit
        self.interactiveEmbed = interactiveEmbed
        overlay.show(selection: selection, label: label, editing: inlineEdit != nil, embed: interactiveEmbed)
        updateCaret()
        if startedEditing, let webView = session.canvas.subviews.first(where: { $0 is WKWebView }) {
            window?.makeFirstResponder(webView) // Keys go to the text being edited.
        }
        if inlineEdit == nil, window?.firstResponder is WKWebView { window?.makeFirstResponder(overlay) }
    }

    /// The caret is drawn by Cue, never by WebKit (the page's is transparent).
    private func updateCaret() {
        guard let inlineEdit, let rect = inlineEdit.caret else {
            caret.isHidden = true
            caret.setFocused(false)
            return
        }
        caret.isHidden = false
        caret.setFocused(true)
        caret.setRangedSelection(!inlineEdit.collapsed)
        caret.moveCaret(to: CGRect(x: rect.minX, y: bounds.height - rect.maxY, width: 2, height: rect.height))
        if inlineEdit.inputCount != lastInputCount {
            lastInputCount = inlineEdit.inputCount
            caret.noteEdit()
        }
    }

    #if DEBUG
    /// The selection overlay as a picture, placed in `view`'s coordinates (for snapshots).
    func overlayImage(in view: NSView) -> (rect: CGRect, image: NSImage)? {
        guard let rep = overlay.bitmapImageRepForCachingDisplay(in: overlay.bounds) else { return nil }
        overlay.cacheDisplay(in: overlay.bounds, to: rep)
        let image = NSImage(size: overlay.bounds.size)
        image.addRepresentation(rep)
        var rect = overlay.convert(overlay.bounds, to: view)
        if view.isFlipped { rect.origin.y = view.bounds.height - rect.maxY }
        return (rect, image)
    }
    #endif

    /// Clicks inside the text being edited, or inside an embed the user is
    /// trying out, belong to the page. ⌘-click always selects.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        let commandDown = NSEvent.modifierFlags.contains(.command)
        if !commandDown, let embed = interactiveEmbed, embed.contains(local) { return session.canvas.hitTest(point) }
        let editedText = inlineEdit == nil ? nil : session.selection?.frame?.insetBy(dx: -4, dy: -4)
        if !commandDown, let editedText, editedText.contains(local) { return session.canvas.hitTest(point) }
        return overlay
    }
}
