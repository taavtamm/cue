import AppKit

/// The stage window. Keys are handled here, before the web view sees them,
/// so a deck's own script can never swallow a clicker press or Esc.
final class ShowWindow: NSWindow {
    /// Return true when the key was a show key and is consumed.
    var onShowKey: ((String) -> Bool)?
    var onMouseMoved: (() -> Void)?
    /// The user closed a rehearsal window: end the show.
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func close() {
        let onClose = onClose
        self.onClose = nil
        super.close()
        onClose?()
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if let name = ShowKeyName.name(for: event), onShowKey?(name) == true { return }
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            onMouseMoved?()
        default:
            break
        }
        super.sendEvent(event)
    }
}
