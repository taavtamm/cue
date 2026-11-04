#if DEBUG
import AppKit
import CueEditor
import CueUI
import SwiftUI

/// Debug-only: saves PNGs of the editor, so it can be checked without
/// screen-recording permission. Same approach as `ShowSnapshots`: SwiftUI
/// chrome via ImageRenderer (glass looks flatter), the real slide and the
/// selection overlay laid on top.
///
///     Cue -open deck.html -snapshotDir /tmp/shots -snapshotSlides 3
@MainActor
enum EditorSnapshots {
    static func captureIfRequested(window: NSWindow?, session: EditorSession) {
        guard let request = ShowSnapshots.request, let window else { return }
        Task {
            try? FileManager.default.createDirectory(at: request.folder, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(4)) // Thumbnails draw.
            for slide in request.slides {
                session.showSlide(slide)
                try? await Task.sleep(for: .seconds(1.5))
                await selectHeading(in: session)
                try? await Task.sleep(for: .seconds(1))
                await save(window, session: session, to: request.folder.appending(path: "editor-slide\(slide + 1).png"))
            }
            for mode in [EditorMode.html, .outline] {
                session.mode = mode
                try? await Task.sleep(for: .seconds(1))
                await save(window, session: session, to: request.folder.appending(path: "editor-\(mode.rawValue).png"))
            }
            session.mode = .design
        }
    }

    /// Selects the slide's first heading, so the snapshot shows the selection box and inspector.
    private static func selectHeading(in session: EditorSession) async {
        guard let slide = session.currentSlide else { return }
        let heading = session.document.sourceMap.elements.first { element in
            element.path.starts(with: slide.elementPath)
                && (element.attributes["role"] == "heading" || ["h1", "h2"].contains(element.tag))
        }
        if let heading { await session.select(cueID: heading.cueID) }
    }

    private static func save(_ window: NSWindow, session: EditorSession, to url: URL) async {
        guard let view = window.contentView, let hosting = view as? NSHostingView<EditorView> else { return }
        let chrome = AnyView(hosting.rootView.environment(\.cueRendersStatically, true))
        let renderers = session.mode == .design ? [session.canvas] : []
        guard let image = await ShowSnapshots.composite(view, chrome: chrome, renderers: renderers) else { return }
        let overlay = container(in: view).flatMap { $0.overlayImage(in: view) }
        let final = NSImage(size: image.size, flipped: false) { bounds in
            image.draw(in: bounds)
            if let overlay { overlay.image.draw(in: overlay.rect) }
            return true
        }
        guard let tiff = final.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    private static func container(in view: NSView) -> CanvasContainerView? {
        if let match = view as? CanvasContainerView { return match }
        for child in view.subviews {
            if let match = container(in: child) { return match }
        }
        return nil
    }
}
#endif
