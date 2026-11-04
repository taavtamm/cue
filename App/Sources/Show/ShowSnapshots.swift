#if DEBUG
import AppKit
import CueCore
import CueRender
import SwiftUI

/// Debug-only: saves PNGs of a running show, so it can be checked without
/// screen-recording permission. SwiftUI chrome is drawn with ImageRenderer
/// at the window's size, then each slide renderer's own snapshot is laid
/// over it (neither web views nor SwiftUI draw through `cacheDisplay`).
/// ImageRenderer approximates system glass, so glass looks flatter here.
///
///     Cue -open deck.html -rehearse YES -snapshotDir /tmp/shots -snapshotSlides 1,2,6
@MainActor
enum ShowSnapshots {
    static var request: (folder: URL, slides: [Int])? {
        guard let path = UserDefaults.standard.string(forKey: "snapshotDir") else { return nil }
        let slides = (UserDefaults.standard.string(forKey: "snapshotSlides") ?? "1")
            .split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map { $0 - 1 }
        return (URL(filePath: path), slides)
    }

    /// For each requested slide: jump there, let embeds animate, save every window.
    static func capture(session: ShowSession, surfaces: () -> [String: ShowSurface]) async {
        guard let request else { return }
        try? FileManager.default.createDirectory(at: request.folder, withIntermediateDirectories: true)
        try? await Task.sleep(for: .seconds(2.5))
        for slide in request.slides {
            session.controller.jump(toSlide: slide)
            session.render()
            try? await Task.sleep(for: .milliseconds(2_500))
            for (key, surface) in surfaces() {
                guard let view = surface.window.contentView,
                      let image = await composite(view, chrome: surface.chrome, renderers: surface.renderers)
                else { continue }
                let sameRole = surfaces().values.filter { $0.role == surface.role }.count > 1
                let name = "\(surface.role.rawValue)\(sameRole ? "-" + key.prefix(8) : "")-slide\(slide + 1).png"
                save(image, to: request.folder.appending(path: name))
            }
        }
    }

    /// Saves a picture of an ordinary window (e.g. Displays) once it has drawn.
    static func capture(window: NSWindow, chrome: AnyView, named name: String) async {
        guard let request, let view = window.contentView else { return }
        try? FileManager.default.createDirectory(at: request.folder, withIntermediateDirectories: true)
        try? await Task.sleep(for: .seconds(1.5))
        if let image = await composite(view, chrome: chrome, renderers: [], drawsUnderTitleBar: true) {
            save(image, to: request.folder.appending(path: name))
        }
    }

    /// `drawsUnderTitleBar`: glass windows (`useCueGlass`) lay their content
    /// out under the title bar, so the chrome isn't pushed down by it.
    static func composite(
        _ view: NSView, chrome: AnyView?, renderers: [SlideRenderer], drawsUnderTitleBar: Bool = false
    ) async -> NSImage? {
        var layers: [(rect: CGRect, image: NSImage)] = []
        for renderer in renderers where renderer.window != nil {
            let image: NSImage
            do { image = try await renderer.snapshot() } catch {
                NSLog("Cue snapshot: %@ renderer not captured (ready: %d): %@",
                      renderer.surface.rawValue, renderer.isReady ? 1 : 0, String(describing: error))
                continue
            }
            var rect = renderer.convert(renderer.bounds, to: view)
            if view.isFlipped { rect.origin.y = view.bounds.height - rect.maxY }
            layers.append((rect, image))
        }
        let base = chrome.flatMap { chrome in
            let content = chrome
                .padding(.top, drawsUnderTitleBar ? 0 : view.safeAreaInsets.top) // A title bar ImageRenderer lacks.
                .environment(\.isSnapshotRendering, true)
                .frame(width: view.bounds.width, height: view.bounds.height)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            return renderer.nsImage
        }
        return NSImage(size: view.bounds.size, flipped: false) { bounds in
            NSColor.black.setFill()
            bounds.fill()
            base?.draw(in: bounds)
            for layer in layers { layer.image.draw(in: layer.rect) }
            return true
        }
    }

    private static func save(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
#endif
