import AppKit
import CueCore
import CueRender

/// Pictures of slides for Claude's `render_slide`: the real deck rendered
/// off screen (export surface: no live embeds start), one slide at a time.
@MainActor
final class SlideSnapshotter {
    private var renderer: SlideRenderer?
    private var window: OffscreenRenderWindow?
    /// The source the renderer has loaded, so repeat calls skip the reload.
    private var loadedSource: String?

    func png(of document: DeckDocument, slide: Int, build: Int?) async throws -> Data {
        let renderer = try await prepared(for: document)
        renderer.show(ShowPosition(slide: slide, build: build ?? 0), finished: build == nil)
        try await Task.sleep(for: .milliseconds(400)) // Fonts, images and the build state settle.
        let image = try await renderer.snapshot()
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw EditorSessionError("Cue couldn't encode the slide picture.")
        }
        return png
    }

    private func prepared(for document: DeckDocument) async throws -> SlideRenderer {
        let canvas = document.structure.canvas
        let size = CGSize(width: 1280, height: (1280 * canvas.height / max(1, canvas.width)).rounded())
        if let renderer, loadedSource == document.source, window?.frame.size == size { return renderer }
        let window = self.window ?? OffscreenRenderWindow(size: size)
        window.setContentSize(size)
        let renderer = self.renderer ?? SlideRenderer(surface: .export)
        window.contentView = renderer
        window.orderFrontRegardless() // WebKit only draws pages in ordered-in windows (parked off screen).
        try await renderer.load(DeckSource(document: document))
        for _ in 0..<200 where !renderer.isReady { try await Task.sleep(for: .milliseconds(25)) }
        guard renderer.isReady else { throw EditorSessionError("The slide didn't finish loading.") }
        self.window = window
        self.renderer = renderer
        loadedSource = document.source
        return renderer
    }

    func close() {
        window?.orderOut(nil)
        window?.contentView = nil
        window?.close()
        window = nil
        renderer = nil
        loadedSource = nil
    }
}

/// A plain message error for the app layer.
struct EditorSessionError: Error, LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
