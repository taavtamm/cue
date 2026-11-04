import AppKit
import CueEditor

/// Keys in the editor that aren't typing:
/// - ↑ / ← previous slide, ↓ / → next slide (when nothing on the slide is
///   selected; with a selection the arrows belong to it).
/// - ⌥⌘↑ / ⌥⌘↓ move the current slide up or down.
/// - Delete removes the current slide when the sidebar was clicked last.
/// Text fields, inline text editing and a live embed being tried keep their keys.
@MainActor
final class EditorKeyRouter {
    struct Actions {
        var delete: (Int) -> Void
        var move: (_ from: Int, _ to: Int) -> Void
    }

    private var monitor: Any?

    init(window: NSWindow, session: EditorSession, actions: Actions) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window, weak session] event in
            guard let window, let session, event.window === window, window.isKeyWindow else { return event }
            return Self.handle(event, in: window, session: session, actions: actions) ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private enum Key: UInt16 {
        case left = 123, right = 124, down = 125, up = 126, delete = 51, forwardDelete = 117
    }

    private static func handle(_ event: NSEvent, in window: NSWindow, session: EditorSession, actions: Actions) -> Bool {
        guard let key = Key(rawValue: event.keyCode), session.mode == .design,
              !(window.firstResponder is NSTextView), // Typing in a field, the notes or the HTML view.
              session.inlineEdit == nil, session.interactiveEmbed == nil
        else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        let vertical = key == .up || key == .down
        let isArrow = vertical || key == .left || key == .right
        if vertical, modifiers == [.command, .option] {
            let offset = key == .up ? -1 : 1
            if let to = SlideReorder.step(session.slide, by: offset, count: session.slideCount) {
                actions.move(session.slide, to)
            }
            return true
        }
        if isArrow, modifiers.isEmpty {
            if session.selection != nil, session.keyFocus == .canvas { return false } // The selection's keys.
            session.showSlide(session.slide + (key == .up || key == .left ? -1 : 1))
            return true
        }
        if key == .delete || key == .forwardDelete, modifiers.isEmpty,
           session.keyFocus == .sidebar, session.slideCount > 1 {
            actions.delete(session.slide)
            return true
        }
        return false
    }
}
