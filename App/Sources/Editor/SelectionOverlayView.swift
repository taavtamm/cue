import AppKit
import CueEditor
import CueUI

/// Draws the selection box (blue #2f7bff, corner handles, a label chip) and
/// turns clicks into selection. Never draws into the page itself.
final class SelectionOverlayView: NSView {
    private let session: EditorSession
    private var selection: CGRect?
    private var label: String?
    private var isEditing = false
    private var embed: CGRect?

    init(session: EditorSession) {
        self.session = session
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("SelectionOverlayView is created in code") }

    override var acceptsFirstResponder: Bool { true }

    func show(selection: CGRect?, label: String?, editing: Bool, embed: CGRect?) {
        let changed = selection != self.selection || label != self.label || editing != isEditing || embed != self.embed
        guard changed else { return }
        (self.selection, self.label, isEditing, self.embed) = (selection, label, editing, embed)
        needsDisplay = true
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        Task { @MainActor [session] in
            if event.clickCount >= 2 && !event.modifierFlags.contains(.command) {
                await session.doubleClick(at: point)
            } else {
                await session.click(at: point)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: session.clearSelection() // Esc
        case 36 where session.selection?.inspection?.isLeaf == true: Task { await session.beginInlineEdit() } // Return
        default: super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        if let embed { drawEmbedFrame(embed) }
        guard let selection, selection.width > 0 else { return }
        let blue = NSColor(CueTheme.selection)
        blue.withAlphaComponent(isEditing ? 0 : 0.06).setFill()
        selection.fill()
        let border = NSBezierPath(roundedRect: selection.insetBy(dx: 0.75, dy: 0.75), xRadius: 3, yRadius: 3)
        border.lineWidth = 1.5
        blue.setStroke()
        border.stroke()
        guard !isEditing else { return }
        for corner in corners(of: selection) { drawHandle(at: corner, color: blue) }
        if let label { drawLabel(label, above: selection, color: blue) }
    }

    private func corners(of rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
    }

    private func drawHandle(at point: CGPoint, color: NSColor) {
        let square = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
        let handle = NSBezierPath(roundedRect: square, xRadius: 2, yRadius: 2)
        NSColor.white.setFill()
        handle.fill()
        handle.lineWidth = 1.5
        color.setStroke()
        handle.stroke()
    }

    /// "h1 · Build 1 · fade up" on a blue chip, sitting on the box's top edge.
    private func drawLabel(_ text: String, above rect: CGRect, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular), .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        var chip = CGRect(x: rect.minX - 0.75, y: rect.maxY, width: size.width + 14, height: size.height + 6)
        if chip.maxY > bounds.maxY { chip.origin.y = rect.maxY - chip.height } // Keep it on the slide.
        color.setFill()
        NSBezierPath(roundedRect: chip, xRadius: 6, yRadius: 6).fill()
        string.draw(at: CGPoint(x: chip.minX + 7, y: chip.minY + 3))
    }

    /// The live embed the user is trying out: dashed cyan, with a hint.
    private func drawEmbedFrame(_ rect: CGRect) {
        let cyan = NSColor(CueTheme.live)
        let path = NSBezierPath(rect: rect.insetBy(dx: 0.75, dy: 0.75))
        path.lineWidth = 1.5
        path.setLineDash([6, 4], count: 2, phase: 0)
        cyan.withAlphaComponent(0.8).setStroke()
        path.stroke()
        let text = "Interacting with live embed · Esc or click outside to stop"
        let hint = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .medium), .foregroundColor: NSColor(CueTheme.liveText),
        ])
        let size = hint.size()
        let chip = CGRect(x: rect.minX + 10, y: rect.minY + 10, width: size.width + 16, height: size.height + 6)
        NSColor(red: 8 / 255, green: 20 / 255, blue: 28 / 255, alpha: 0.86).setFill()
        NSBezierPath(roundedRect: chip, xRadius: 7, yRadius: 7).fill()
        hint.draw(at: CGPoint(x: chip.minX + 8, y: chip.minY + 3))
    }
}
