import AppKit
import CueCore
import CueEditor
import Observation

/// First-slide pictures of recent decks, for the Welcome window. Each is a
/// real render (an offscreen thumbnail surface, no embeds) drawn once and
/// cached as a PNG in Application Support, keyed by path and modification
/// date, so it's redrawn only after the deck changes.
@MainActor @Observable
final class WelcomeThumbnails {
    private(set) var images: [URL: NSImage] = [:]
    @ObservationIgnored let folder: URL
    @ObservationIgnored private var drawing: Task<Void, Never>?

    init(folder: URL = WelcomeThumbnails.defaultFolder) {
        self.folder = folder
    }

    static var defaultFolder: URL {
        URL.applicationSupportDirectory.appending(path: "Cue/Welcome Thumbnails", directoryHint: .isDirectory)
    }

    /// Shows cached pictures at once and draws the missing ones in order.
    func prepare(_ decks: [URL]) {
        var missing: [(URL, ThumbnailCacheKey)] = []
        for deck in decks {
            guard let key = ThumbnailCacheKey(fileAt: deck) else { continue }
            if let cached = NSImage(contentsOf: folder.appending(path: key.fileName)) {
                images[deck] = cached
            } else if deck.pathExtension.lowercased().hasPrefix("htm") {
                missing.append((deck, key))
            } else {
                images[deck] = NSWorkspace.shared.icon(forFile: deck.path) // Not an HTML deck: its file icon.
            }
        }
        drawing?.cancel()
        drawing = Task { [weak self] in
            for (deck, key) in missing where !Task.isCancelled {
                guard let image = await Self.render(deck) else { continue }
                self?.images[deck] = image
                self?.store(image, as: key)
            }
        }
    }

    func cancel() { drawing?.cancel() }

    /// Draws the deck's first slide with the editor's thumbnail store, then
    /// stops it (it would go on to draw every slide).
    private static func render(_ deck: URL) async -> NSImage? {
        guard let document = try? DeckDocument(contentsOf: deck) else { return nil }
        let store = ThumbnailStore(canvas: document.structure.canvas)
        defer { store.close() }
        let loading = Task { await store.load(document) }
        defer { loading.cancel() }
        for _ in 0..<300 { // Up to 15 s for a heavy deck.
            if let image = store.images[0] { return image }
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { return nil }
        }
        return nil
    }

    private func store(_ image: NSImage, as key: ThumbnailCacheKey) {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? png.write(to: folder.appending(path: key.fileName), options: .atomic)
    }
}
