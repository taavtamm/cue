import AppKit
import CueCore
import CueRender
import Observation

/// Slide thumbnails for the sidebar: real renders of the deck, never stand-in
/// pictures. One offscreen `.thumbnail` surface (no embeds start there) shows
/// each slide in its finished state and snapshots it. Edits reach it live, and
/// only the slides they touch are drawn again.
@MainActor @Observable
public final class ThumbnailStore {
    public private(set) var images: [Int: NSImage] = [:]

    @ObservationIgnored let renderer = SlideRenderer(surface: .thumbnail)
    @ObservationIgnored private let window: OffscreenRenderWindow
    @ObservationIgnored private var pending: [Int] = []
    @ObservationIgnored private var drawing: Task<Void, Never>?
    @ObservationIgnored private var slideCount = 0
    /// The slides' identities when they were last drawn, to follow moves.
    @ObservationIgnored private var slideIDs: [String] = []

    public init(canvas: CanvasSize, width: CGFloat = 384) {
        let size = CGSize(width: width, height: (width * canvas.height / max(1, canvas.width)).rounded())
        window = OffscreenRenderWindow(size: size)
        window.contentView = renderer
        window.orderFrontRegardless() // WebKit only renders pages in windows on screen.
    }

    /// Loads the deck and draws every slide. Pictures of slides that are
    /// still in the deck stay up (moved to their new place) until redrawn,
    /// so the sidebar never blanks; new or changed slides are drawn first.
    public func load(_ document: DeckDocument) async {
        let ids = SlideIdentity.ids(document.structure.slides)
        let moved = SlideIdentity.mapping(before: slideIDs, after: ids)
        var kept: [Int: NSImage] = [:]
        for (old, new) in moved { kept[new] = images[old] }
        images = kept
        slideIDs = ids
        slideCount = ids.count
        drawing?.cancel()
        drawing = nil
        pending = []
        renderer.sourceManifest = document.liveManifest
        do {
            try await renderer.load(DeckSource(document: document))
        } catch {
            return
        }
        let fresh = (0..<slideCount).filter { kept[$0] == nil }
        redraw(fresh + (0..<slideCount).filter { kept[$0] != nil })
    }

    /// Brings the thumbnails up to date with an edit made on `slide`.
    public func update(after result: EditResult, in document: DeckDocument, slide: Int) async {
        if result.structureChanged || result.live == .reload || document.structure.slides.count != slideCount {
            await load(document)
            return
        }
        try? await renderer.applyLive(result.live, from: document)
        redraw([slide])
    }

    public func close() {
        drawing?.cancel()
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }

    private func redraw(_ slides: [Int]) {
        pending.append(contentsOf: slides.filter { !pending.contains($0) })
        guard drawing == nil else { return }
        drawing = Task { [weak self] in
            await self?.drawPending()
            self?.drawing = nil
        }
    }

    private func drawPending() async {
        while !pending.isEmpty, !Task.isCancelled {
            let slide = pending.removeFirst()
            guard slide < slideCount else { continue } // Deleted meanwhile.
            if let image = await draw(slide), !Task.isCancelled { images[slide] = image }
        }
    }

    private func draw(_ slide: Int) async -> NSImage? {
        guard await waitUntilReady() else { return nil }
        renderer.show(ShowPosition(slide: slide), finished: true)
        for _ in 0..<50 { // Until the page has applied the slide.
            let current = try? await renderer.evaluateInBridge("return window.__cue.debug().current.slide") as? Int
            if current == slide { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        try? await Task.sleep(for: .milliseconds(120)) // Fonts and images settle.
        return try? await renderer.snapshot()
    }

    private func waitUntilReady() async -> Bool {
        for _ in 0..<500 where !renderer.isReady {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return renderer.isReady
    }
}
