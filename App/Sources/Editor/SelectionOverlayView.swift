import AppKit
import CueCore
import CueEditor
import CueUI

/// Draws the selection box (blue #2f7bff, handles, a label chip), snapping
/// guides while dragging, and turns clicks, drags and keys into selection,
/// moves and resizes (see `SelectionOverlayView+Input`). Never draws into
/// the page itself.
final class SelectionOverlayView: NSView {
    let session: EditorSession
    weak var container: CanvasContainerView?
    private(set) var selection: CGRect?
    private var label: String?
    private(set) var isEditing = false
    private var embed: CGRect?
    /// The move or resize in progress, drawn instead of the selection.
    var drag: ElementDrag? { didSet { needsDisplay = true } }
    /// Where a drag ended, shown until the page reports the element's new box.
    var settledFrame: CGRect?
    var gesture = PointerGesture()

    init(session: EditorSession) {
        self.session = session
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("SelectionOverlayView is created in code") }

    override var acceptsFirstResponder: Bool { true }

    func show(selection: CGRect?, label: String?, editing: Bool, embed: CGRect?) {
        if selection != self.selection { settledFrame = nil } // The page has the element's new box.
        let changed = selection != self.selection || label != self.label || editing != isEditing || embed != self.embed
        guard changed else { return }
        (self.selection, self.label, isEditing, self.embed) = (selection, label, editing, embed)
        needsDisplay = true
    }

    /// The box to draw and drag: the live drag, else where one just ended, else the selection.
    var currentBox: CGRect? { drag?.viewFrame ?? settledFrame ?? selection }

    /// Which handle (if any) is under `point`, for a box `rect`.
    func handle(at point: CGPoint, in rect: CGRect) -> ElementPlacement.Handle? {
        for (corner, handle) in handles(of: rect) where CGRect(x: corner.x - 7, y: corner.y - 7, width: 14, height: 14).contains(point) {
            return handle
        }
        return nil
    }

    /// The eight handles, as view points and which edges they drag (canvas +y is down).
    private func handles(of rect: CGRect) -> [(CGPoint, ElementPlacement.Handle)] {
        [(CGPoint(x: rect.minX, y: rect.maxY), [.left, .top]), (CGPoint(x: rect.maxX, y: rect.maxY), [.right, .top]),
         (CGPoint(x: rect.minX, y: rect.minY), [.left, .bottom]), (CGPoint(x: rect.maxX, y: rect.minY), [.right, .bottom]),
         (CGPoint(x: rect.midX, y: rect.maxY), .top), (CGPoint(x: rect.midX, y: rect.minY), .bottom),
         (CGPoint(x: rect.minX, y: rect.midY), .left), (CGPoint(x: rect.maxX, y: rect.midY), .right)]
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        if let embed { drawEmbedFrame(embed) }
        if let drag { drawGuides(drag) }
        guard let selection = currentBox, selection.width > 0 else { return }
        let blue = NSColor(CueTheme.selection)
        blue.withAlphaComponent(isEditing ? 0 : 0.06).setFill()
        selection.fill()
        let border = NSBezierPath(roundedRect: selection.insetBy(dx: 0.75, dy: 0.75), xRadius: 3, yRadius: 3)
        border.lineWidth = 1.5
        blue.setStroke()
        border.stroke()
        guard !isEditing else { return }
        for (point, _) in handles(of: selection) { drawHandle(at: point, color: blue) }
        if let label, drag == nil { drawLabel(label, above: selection, color: blue) }
    }

    /// Thin magenta lines across the slide where the box snapped.
    private func drawGuides(_ drag: ElementDrag) {
        let slide = drag.geometry.frame
        NSColor(red: 1, green: 0.37, blue: 0.64, alpha: 0.95).setStroke()
        for guide in drag.guides {
            let path = NSBezierPath()
            path.lineWidth = 1
            switch guide.axis {
            case .vertical:
                let x = (slide.minX + guide.position * drag.geometry.scale).rounded() + 0.5
                path.move(to: CGPoint(x: x, y: slide.minY))
                path.line(to: CGPoint(x: x, y: slide.maxY))
            case .horizontal:
                let y = (slide.maxY - guide.position * drag.geometry.scale).rounded() + 0.5
                path.move(to: CGPoint(x: slide.minX, y: y))
                path.line(to: CGPoint(x: slide.maxX, y: y))
            }
            path.stroke()
        }
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
