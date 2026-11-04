import AppKit
import CueEditor

/// Zooming the canvas: pinch about the fingers, two-finger double-tap for
/// fit ↔ 200%, ⌘+ ⌘− ⌘0. Two-finger scrolling pans (the scroll view does
/// that). The slide re-renders at the new size, so it stays sharp.
extension CanvasContainerView {
    /// Pinch. `point` is in the content's coordinates.
    func magnify(by amount: CGFloat, at point: CGPoint) {
        let old = session.zoom.scale
        let new = session.zoom.set(old * (1 + amount))
        guard new != old else { return }
        applyZoom(new, anchor: point)
    }

    func smartMagnify(at point: CGPoint) {
        zoom(to: session.zoom.smartMagnified(), anchor: point)
    }

    /// Changes zoom, keeping `anchor` (content coordinates) still, or the centre.
    func zoom(to scale: CGFloat, anchor: CGPoint? = nil) {
        let new = session.zoom.set(scale)
        applyZoom(new, anchor: anchor)
    }

    /// After a slide change: keep the zoom, look at the middle of the slide.
    func recentre() {
        guard !session.zoom.isFit else { return }
        let visible = scrollView.contentView.bounds.size
        let origin = CGPoint(x: (content.bounds.width - visible.width) / 2, y: (content.bounds.height - visible.height) / 2)
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// ⌘= / ⌘+ zoom in, ⌘− zoom out, ⌘0 fits the slide.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard window?.isKeyWindow == true, let key = event.charactersIgnoringModifiers?.lowercased()
        else { return super.performKeyEquivalent(with: event) }
        if flags == [.command, .option], key == "t" || key == "†" {
            EditorInsert.textBox(session)
            return true
        }
        if flags == [.command, .option], key == "i" || key == "ˆ" {
            EditorInsert.chooseImage(session)
            return true
        }
        guard flags == .command else { return super.performKeyEquivalent(with: event) }
        switch key {
        case "=", "+": zoom(to: session.zoom.zoomedIn())
        case "-": zoom(to: session.zoom.zoomedOut())
        case "0": zoom(to: 1)
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }
}
