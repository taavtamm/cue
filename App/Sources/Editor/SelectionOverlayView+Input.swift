import AppKit
import CueCore
import CueEditor

/// Clicks, drags, keys, gestures and dropped files on the canvas.
extension SelectionOverlayView {
    // MARK: Pointer

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let command = event.modifierFlags.contains(.command)
        gesture = PointerGesture(start: point, duplicates: event.modifierFlags.contains(.option))
        if event.clickCount >= 2 && !command {
            Task { @MainActor [session] in await session.doubleClick(at: point) }
            return
        }
        if !isEditing, let box = currentBox, session.selection != nil {
            if let handle = handle(at: point, in: box) {
                gesture.intent = .drag(.resize(handle))
                return
            }
            if box.contains(point) && !command {
                gesture.intent = .drag(.move) // A click without a drag still selects what's there (on mouse up).
                return
            }
        }
        gesture.intent = .selectThenMove
        gesture.selecting = Task { @MainActor [session] in _ = await session.click(at: point) }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard gesture.intent != .none, !isEditing else { return }
        if var current = drag {
            let delta = current.geometry.canvasDelta(fromView: CGSize(width: point.x - gesture.start.x,
                                                                    height: point.y - gesture.start.y))
            current.update(delta: delta, shift: event.modifierFlags.contains(.shift),
                           noSnapping: event.modifierFlags.contains(.command))
            drag = current
            session.preview(current)
            return
        }
        guard !gesture.isPreparing, gesture.passedThreshold(at: point) else { return }
        gesture.hasMoved = true
        gesture.isPreparing = true
        let kind: ElementDrag.Kind = if case .drag(let kind) = gesture.intent { kind } else { .move }
        let selecting = gesture.selecting
        Task { @MainActor in
            await selecting?.value // Let the click's selection land first.
            drag = await session.beginDrag(kind)
            gesture.isPreparing = false
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        defer { gesture = PointerGesture() }
        if let finished = drag {
            settledFrame = finished.viewFrame
            drag = nil
            let duplicate = gesture.duplicates || event.modifierFlags.contains(.option)
            Task { @MainActor [session] in await session.commit(finished, duplicate: duplicate) }
            return
        }
        // Pressed on the selection but didn't drag: an ordinary click (it may pick a child).
        if case .drag(.move) = gesture.intent, !gesture.hasMoved {
            Task { @MainActor [session] in await session.click(at: point) }
        }
    }

    // MARK: Keys

    override func keyDown(with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let step: CGFloat = shift ? 10 : 1
        switch event.keyCode {
        case 53: // Esc
            if let current = drag {
                drag = nil
                Task { await session.cancel(current) }
            } else {
                session.clearSelection()
            }
        case 36 where session.selection != nil: Task { await session.beginInlineEdit() } // Return
        case 51, 117: Task { await session.deleteSelection() } // ⌫, ⌦ (nothing happens without a selection)
        case 123: Task { await session.nudge(dx: -step, dy: 0) }
        case 124: Task { await session.nudge(dx: step, dy: 0) }
        case 125: Task { await session.nudge(dx: 0, dy: step) }
        case 126: Task { await session.nudge(dx: 0, dy: -step) }
        default: super.keyDown(with: event)
        }
    }

    @objc func copy(_ sender: Any?) { session.copySelection() }
    @objc func paste(_ sender: Any?) { Task { await session.paste() } }
    @objc func cut(_ sender: Any?) {
        session.copySelection()
        Task { await session.deleteSelection() }
    }
    @objc func delete(_ sender: Any?) { Task { await session.deleteSelection() } }
    @objc func duplicate(_ sender: Any?) { Task { await session.duplicateSelection() } }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers else { return super.performKeyEquivalent(with: event) }
        switch key {
        case "d": duplicate(nil)
        case "]": Task { await session.restack(by: 1) }
        case "[": Task { await session.restack(by: -1) }
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    // MARK: Trackpad

    override func magnify(with event: NSEvent) {
        container?.magnify(by: event.magnification, at: convert(event.locationInWindow, from: nil))
    }

    override func smartMagnify(with event: NSEvent) {
        container?.smartMagnify(at: convert(event.locationInWindow, from: nil))
    }

    // MARK: Dropped images

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        Self.imageURLs(sender).isEmpty && !Self.hasImageData(sender) ? [] : .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let point = convert(sender.draggingLocation, from: nil)
        let urls = Self.imageURLs(sender)
        let data = sender.draggingPasteboard.data(forType: .png) ?? sender.draggingPasteboard.data(forType: .tiff)
        guard !urls.isEmpty || data != nil else { return false }
        Task { @MainActor [session] in
            let centre = await session.canvasPoint(fromView: point)
            if urls.isEmpty, let data {
                await session.insertImage(data: data, centredAt: centre)
            }
            for url in urls { await session.insertImage(contentsOf: url, centredAt: centre) }
        }
        return true
    }

    private static func imageURLs(_ info: any NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingContentsConformToTypes: ["public.image"]]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    private static func hasImageData(_ info: any NSDraggingInfo) -> Bool {
        info.draggingPasteboard.availableType(from: [.png, .tiff]) != nil
    }
}
