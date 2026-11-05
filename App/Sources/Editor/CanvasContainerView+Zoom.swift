import AppKit
import CueEditor

/// Zooming the canvas: pinch about the fingers, two-finger double-tap for
/// fit ↔ 200%, ⌘+ ⌘− ⌘0. Two-finger scrolling pans (the scroll view does
/// that). The slide re-renders at the new size, so it stays sharp.
extension CanvasContainerView {
    /// A trackpad pinch. While the fingers move, the scroll view magnifies
    /// what is already on screen (GPU-smooth). When they lift, the slide is
    /// re-rendered once at the new size, so it's sharp again, with the same
    /// spot under the fingers. Resizing the page on every event juddered.
    func pinch(_ event: NSEvent) {
        let base = appliedZoom
        switch event.phase {
        case .began, .changed:
            let current = base * scrollView.magnification
            let target = min(CanvasZoom.range.upperBound, max(CanvasZoom.range.lowerBound, current * (1 + event.magnification)))
            scrollView.setMagnification(target / base, centeredAt: content.convert(event.locationInWindow, from: nil))
        case .ended, .cancelled:
            finishPinch(at: event.locationInWindow)
        default:
            if event.phase.isEmpty { // A mouse or a device without gesture phases.
                magnify(by: event.magnification, at: content.convert(event.locationInWindow, from: nil))
            }
        }
    }

    /// Turns the live magnification into a real zoom: content re-sized and
    /// re-rendered, scrolled so the content point under the fingers stays put.
    private func finishPinch(at windowPoint: CGPoint) {
        let magnification = scrollView.magnification
        guard abs(magnification - 1) > 0.001 else { return }
        let clip = scrollView.contentView
        let pointer = content.convert(windowPoint, from: nil) // Content units, before the change.
        let inClip = clip.convert(windowPoint, from: nil)
        let clipOrigin = clip.bounds.origin
        let old = appliedZoom
        let new = session.zoom.set(old * magnification)
        scrollView.magnification = 1
        applyZoom(new, anchor: nil)
        scrollKeepingInBounds(to: CanvasZoom.originAfterPinch(
            pointer: pointer, pointerInClip: inClip, clipOrigin: clipOrigin, magnification: magnification, old: old, new: new
        ))
    }

    private func scrollKeepingInBounds(to origin: CGPoint) {
        let visible = scrollView.contentView.bounds.size
        let maxX = max(0, content.frame.width - visible.width), maxY = max(0, content.frame.height - visible.height)
        scrollView.contentView.scroll(to: CGPoint(x: min(max(0, origin.x), maxX), y: min(max(0, origin.y), maxY)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// Pinch without gesture phases. `point` is in the content's coordinates.
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
