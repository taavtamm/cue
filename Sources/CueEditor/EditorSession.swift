import AppKit
import CueCore
import CueRender
import Foundation
import Observation

/// One deck open in the editor: the document, the slide on the canvas, the
/// selection, and every edit. Edits go through `DeckDocument.apply`, so each
/// is a minimal patch with undo; the canvas catches up live.
@MainActor @Observable
public final class EditorSession {
    public internal(set) var document: DeckDocument
    public internal(set) var slide = 0
    public internal(set) var selection: EditorSelection?
    public var mode: EditorMode = .design
    public internal(set) var isPlayingLive = true
    public internal(set) var liveSlides: Set<Int>
    public internal(set) var lastEditedAt: Date?
    /// Why the last edit was refused, in plain words. Cleared by the next edit.
    public var lastError: String?
    public internal(set) var animations = SlideAnimations(tracks: [], embedCount: 0)
    /// What keeps the GPU busy, per slide shown so far (0-based). Measured
    /// again each time a slide is shown, so a lighter deck clears its warning.
    public internal(set) var loads: [Int: SlideLoad] = [:]
    /// The live embed taking clicks after a double-click, in canvas coordinates.
    public internal(set) var interactiveEmbed: CGRect?
    public internal(set) var inlineEdit: InlineEditState?
    public let askQueue: AskRequestQueue
    /// Claude's change sets in this window.
    public let claudeChanges = ClaudeChanges()
    /// Called when the user sends something from the Ask bar (the app hands it to Claude).
    @ObservationIgnored public var onAsk: ((AskRequest) -> Void)?
    /// The real slide, as an editor surface.
    public let canvas = SlideRenderer(surface: .editor)
    /// How far the canvas is zoomed in (per window, not saved).
    public let zoom = CanvasZoom()

    /// Called after every successful edit, undo or redo (thumbnails, window title).
    @ObservationIgnored public var onDocumentChanged: ((EditResult) -> Void)?
    /// Where the last click was: decides what arrows and Delete do.
    public var keyFocus = EditorKeyFocus.canvas
    @ObservationIgnored var editChain: Task<Void, Never>?
    /// Callers of `finishInteractions()` waiting for the page's final text.
    @ObservationIgnored var inlineCommitWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored var notesDebounce: [Int: Task<Void, Never>] = [:]

    public init(document: DeckDocument, askQueue: AskRequestQueue = AskRequestQueue()) {
        self.document = document
        self.askQueue = askQueue
        liveSlides = Set(document.structure.slides.indices.filter { document.structure.slides[$0].hasLiveContent })
        canvas.onEvent = { [weak self] event in self?.handle(event) }
    }

    public var structure: DeckStructure { document.structure }
    public var slideCount: Int { structure.slides.count }
    public var currentSlide: SlideInfo? { structure.slides.indices.contains(slide) ? structure.slides[slide] : nil }
    public var isDirty: Bool { document.isDirty }
    public var canUndo: Bool { document.history.canUndo }
    public var canRedo: Bool { document.history.canRedo }

    public var title: String {
        let name = document.fileURL.deletingPathExtension().lastPathComponent
        return name.isEmpty ? "Untitled" : name
    }

    /// "HTML · 1920 × 1080 · 12 slides".
    public var summary: String {
        let size = "\(Int(structure.canvas.width)) × \(Int(structure.canvas.height))"
        return "HTML · \(size) · \(slideCount == 1 ? "1 slide" : "\(slideCount) slides")"
    }

    /// When the deck last changed: the last edit here, else the file's date.
    public var editedAt: Date? {
        lastEditedAt ?? (try? document.fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
    }

    // MARK: Canvas

    /// Loads the deck into the canvas, tagged for source mapping.
    public func loadCanvas() async throws {
        canvas.sourceManifest = document.liveManifest
        try await canvas.load(DeckSource(document: document), at: ShowPosition(slide: slide))
        canvas.show(ShowPosition(slide: slide), finished: true)
        if !isPlayingLive { canvas.setPaused(true) }
    }

    public func showSlide(_ index: Int) {
        let target = min(max(0, index), max(0, slideCount - 1))
        endInteractions()
        selection = nil
        slide = target
        canvas.show(ShowPosition(slide: target), finished: true)
        Task { await refreshAnimations() }
        measureLoadSoon()
    }

    /// Play or pause live content (Web Animations, media) on the canvas.
    /// Scripts with their own animation loops keep running.
    public func setPlayingLive(_ playing: Bool) {
        isPlayingLive = playing
        canvas.setPaused(!playing)
    }

    func handle(_ event: BridgeEvent) {
        switch event {
        case .ready:
            Task {
                await refreshSelection()
                await refreshAnimations()
                measureLoadSoon()
            }
        case .liveContent(let slides):
            liveSlides.formUnion(slides)
        case .textEditing(let event):
            handleInlineText(event)
        default:
            break
        }
    }

    // MARK: Ask bar

    /// Queues a request for Claude; a connected session takes it over MCP.
    @discardableResult
    public func ask(_ text: String) -> AskRequest? {
        guard let request = askQueue.enqueue(text, slide: slide, selection: selection?.path) else { return nil }
        onAsk?(request)
        return request
    }

    /// Requests typed here that no Claude session has finished yet.
    public var waitingRequests: Int { askQueue.open.count }
}
