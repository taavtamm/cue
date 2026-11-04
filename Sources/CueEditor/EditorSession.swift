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
    /// The live embed taking clicks after a double-click, in canvas coordinates.
    public internal(set) var interactiveEmbed: CGRect?
    public internal(set) var inlineEdit: InlineEditState?
    public let askQueue: AskRequestQueue
    /// The real slide, as an editor surface.
    public let canvas = SlideRenderer(surface: .editor)

    /// Called after every successful edit, undo or redo (thumbnails, window title).
    @ObservationIgnored public var onDocumentChanged: ((EditResult) -> Void)?
    @ObservationIgnored var editChain: Task<Bool, Never>?
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

    /// Queues a request for Claude (served over MCP in milestone 7).
    @discardableResult
    public func ask(_ text: String) -> AskRequest? {
        askQueue.enqueue(text, slide: slide, selection: selection?.path)
    }

    /// Requests typed here that no Claude session has finished yet.
    public var waitingRequests: Int { askQueue.open.count }
}
