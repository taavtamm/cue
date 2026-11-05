import AppKit
import CueEditor
import CueUI
import SwiftUI
import WebKit

/// Holds the editor's slide surface, the selection overlay, the glowing caret
/// and the format bar, inside a scroll view so the slide can be zoomed and
/// panned. Everything lives in one zoomable document view, so native drawing
/// follows zoom and scroll for free.
///
/// Decides who gets each click: the overlay selects; while editing text or
/// trying out an embed, clicks inside it go to the page.
final class CanvasContainerView: NSView {
    let session: EditorSession
    let scrollView = NSScrollView()
    /// Sized to the visible area × zoom; the slide renders sharp at that size.
    let content = NSView()
    let overlay: SelectionOverlayView
    private let caret = CaretOverlayView()
    private let formatBar: NSHostingView<FormatBar>
    private var inlineEdit: InlineEditState?
    private var interactiveEmbed: CGRect?
    private var lastInputCount = 0
    private var resizeRefresh: Task<Void, Never>?
    /// The zoom the content is sized for, and the slide it was last centred on.
    private(set) var appliedZoom: CGFloat = 1
    /// Stands in for the canvas while it re-renders after a zoom change.
    var zoomCover: NSImageView?
    var zoomGeneration = 0
    var shownSlide = -1

    init(session: EditorSession) {
        self.session = session
        overlay = SelectionOverlayView(session: session)
        formatBar = NSHostingView(rootView: FormatBar { command in
            Task { await session.format(EditorSession.TextFormat(rawValue: command.rawValue) ?? .bold) }
        })
        super.init(frame: .zero)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false
        // Live pinch magnification (see `pinch`); the real zoom is the content's size.
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = CanvasZoom.range.upperBound
        scrollView.documentView = content
        addSubview(scrollView)
        for view in [session.canvas, overlay, caret] as [NSView] { content.addSubview(view) }
        content.addSubview(formatBar)
        caret.isHidden = true
        formatBar.isHidden = true
        overlay.container = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("CanvasContainerView is created in code") }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        applyZoom(session.zoom.scale, anchor: nil)
    }

    /// SwiftUI resizes this view (e.g. when a banner slides in above it)
    /// without AppKit always asking it to lay out again, which left the
    /// slide at its old size, pushed down and cut off. Re-fit on every resize.
    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        super.setFrameSize(newSize)
        if changed {
            needsLayout = true
            layoutSubtreeIfNeeded()
        }
    }

    /// Sizes the content for `scale`, keeping `anchor` (in content
    /// coordinates) under the same spot, or the centre when nil.
    func applyZoom(_ scale: CGFloat, anchor: CGPoint?) {
        let old = content.frame.width / max(1, scrollView.contentSize.width)
        let visible = scrollView.contentView.bounds
        appliedZoom = scale
        // The scroll view's own size, read after it was just set to our bounds.
        // Rounded down: a content half a point larger than the view scrolls.
        let size = CGSize(width: (scrollView.frame.width * scale).rounded(.down),
                          height: (scrollView.frame.height * scale).rounded(.down))
        let point = anchor ?? CGPoint(x: visible.midX, y: visible.midY)
        let origin = CanvasZoom.anchoredOrigin(anchor: point, visibleOrigin: visible.origin,
                                               old: old > 0 ? old : 1, new: scale)
        if content.frame.size != size {
            content.frame = CGRect(origin: .zero, size: size)
            for view in [session.canvas, overlay, caret] as [NSView] { view.frame = content.bounds }
        }
        let maxX = max(0, size.width - visible.width), maxY = max(0, size.height - visible.height)
        scrollView.contentView.scroll(to: CGPoint(x: min(max(0, origin.x), maxX), y: min(max(0, origin.y), maxY)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        scheduleSelectionRefresh()
    }

    private func scheduleSelectionRefresh() {
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
        placeFormatBar(above: inlineEdit == nil ? nil : selection)
        if startedEditing, let webView = session.canvas.subviews.first(where: { $0 is WKWebView }) {
            window?.makeFirstResponder(webView) // Keys go to the text being edited.
        }
        if inlineEdit == nil, window?.firstResponder is WKWebView { window?.makeFirstResponder(overlay) }
    }

    /// Above the text being edited, or below it when there's no room.
    private func placeFormatBar(above rect: CGRect?) {
        guard let rect else { return formatBar.isHidden = true }
        let size = formatBar.fittingSize
        var origin = CGPoint(x: rect.minX, y: rect.maxY + 10)
        if origin.y + size.height > content.bounds.maxY { origin.y = rect.minY - size.height - 10 }
        formatBar.frame = CGRect(origin: origin, size: size)
        formatBar.isHidden = false
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
        caret.moveCaret(to: CGRect(x: rect.minX, y: content.bounds.height - rect.maxY, width: 2, height: rect.height))
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
        // Glass in an AppKit-hosted view caches as nothing; draw the bar with SwiftUI instead.
        let bar: NSImage? = formatBar.isHidden ? nil : {
            let renderer = ImageRenderer(content: FormatBar { _ in }.environment(\.cueRendersStatically, true))
            renderer.scale = 2
            return renderer.nsImage
        }()
        let barFrame = formatBar.frame
        let image = NSImage(size: overlay.bounds.size, flipped: false) { bounds in
            rep.draw(in: bounds)
            bar?.draw(in: barFrame)
            return true
        }
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
        if let scroller = [scrollView.verticalScroller, scrollView.horizontalScroller]
            .compactMap({ $0 }).first(where: { !$0.isHidden && $0.frame.contains(scrollView.convert(local, from: self)) }) {
            return scroller
        }
        let inContent = content.convert(local, from: self)
        if !formatBar.isHidden, formatBar.frame.contains(inContent) {
            return formatBar.hitTest(content.convert(inContent, to: formatBar.superview))
        }
        let commandDown = NSEvent.modifierFlags.contains(.command)
        if !commandDown, let embed = interactiveEmbed, embed.contains(inContent) {
            return session.canvas.hitTest(content.convert(inContent, to: session.canvas.superview))
        }
        let editedText = inlineEdit == nil ? nil : session.selection?.frame?.insetBy(dx: -4, dy: -4)
        if !commandDown, let editedText, editedText.contains(inContent) {
            return session.canvas.hitTest(content.convert(inContent, to: session.canvas.superview))
        }
        return overlay
    }
}
