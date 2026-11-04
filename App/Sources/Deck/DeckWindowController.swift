import AppKit
import CueCore
import CueEditor
import CueRender
import SwiftUI

/// One deck's editor window. Owns the editing session, the thumbnails, the
/// show and the Displays window; the views are in App/Sources/Editor.
@MainActor
final class DeckWindowController: NSWindowController, NSWindowDelegate {
    let session: EditorSession
    var deck: DeckDocument { session.document }
    var onClose: (() -> Void)?

    let thumbnails: ThumbnailStore
    private var show: ShowSession?
    private lazy var displays = DisplayCoordinator(sidecarURL: deck.sidecarURL)
    private var displaysWindow: DisplaysWindowController?
    private lazy var network = DeckNetworkAccess(document: deck)

    init(deck: DeckDocument) {
        session = EditorSession(document: deck)
        thumbnails = ThumbnailStore(canvas: deck.structure.canvas)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1484, height: 954),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.minSize = CGSize(width: 1100, height: 720)
        window.setFrameAutosaveName("EditorWindow")
        super.init(window: window)
        window.title = session.title
        window.representedURL = deck.fileURL
        window.delegate = self
        window.useCueGlass(makeEditor())
        if window.frame.origin == .zero { window.center() }
        wireUp()
        Task { await load() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("DeckWindowController is created in code") }

    private func makeEditor() -> some View {
        EditorView(
            session: session, thumbnails: thumbnails, actions: makeActions(),
            networkBanner: AnyView(NetworkAccessBanner(access: network))
        )
    }

    private func wireUp() {
        session.canvas.onSandboxEvent = { [weak self] event in self?.network.handle(event) }
        network.onAllowed = { [weak self] in Task { await self?.load() } } // Reload with the newly allowed hosts.
        session.onDocumentChanged = { [weak self] result in
            guard let self else { return }
            self.window?.isDocumentEdited = self.session.isDirty
            Task { await self.thumbnails.update(after: result, in: self.session.document, slide: self.session.slide) }
        }
    }

    private func load() async {
        do {
            try await session.loadCanvas()
        } catch {
            DeckOpener.reportFailure(opening: deck.fileURL, error: error)
            return
        }
        await thumbnails.load(session.document)
        #if DEBUG
        EditorSnapshots.captureIfRequested(window: window, session: session) { [unowned self] in
            AnyView(self.makeEditor())
        }
        #endif
    }

    private func makeActions() -> EditorActions {
        EditorActions(
            play: { [weak self] slide in self?.present(fromSlide: slide) },
            rehearse: { [weak self] in self?.rehearse(nil) },
            showDisplays: { [weak self] in self?.showDisplays(nil) },
            addSlide: { [weak self] in self?.edit(.addSlide(after: self?.session.slide ?? 0, html: nil), thenShow: 1) },
            duplicateSlide: { [weak self] index in self?.duplicate(index) },
            deleteSlide: { [weak self] index in self?.edit(.deleteSlide(index), thenShow: 0) },
            moveSlide: { [weak self] from, to in self?.move(from, to) }
        )
    }

    // MARK: Slide structure

    /// Applies a structural edit, then shows the slide `offset` after the current one.
    private func edit(_ operation: EditOperation, thenShow offset: Int) {
        Task {
            let target = session.slide + offset
            if await session.apply(operation) { session.showSlide(target) }
        }
    }

    private func duplicate(_ index: Int) {
        guard session.structure.slides.indices.contains(index),
              let range = session.structure.slides[index].sourceRange else { return }
        let source = session.document.source as NSString
        let html = source.substring(with: NSRange(location: range.start, length: range.length))
        Task {
            if await session.apply(.addSlide(after: index, html: html)) { session.showSlide(index + 1) }
        }
    }

    private func move(_ from: Int, _ to: Int) {
        Task {
            if await session.apply(.moveSlide(from: from, to: to)) { session.showSlide(to) }
        }
    }

    // MARK: Showing

    @objc func playSlideshow(_ sender: Any?) { present(fromSlide: session.slide) }
    @objc func playFromStart(_ sender: Any?) { present(fromSlide: 0) }
    @objc func rehearse(_ sender: Any?) { present(fromSlide: session.slide, mode: .rehearse) }

    @objc func showDisplays(_ sender: Any?) {
        let controller = displaysWindow ?? DisplaysWindowController(
            coordinator: displays,
            onRehearse: { [weak self] in self?.rehearse(nil) },
            onStart: { [weak self] in self?.playSlideshow(nil) }
        )
        displaysWindow = controller
        controller.showWindow(nil)
        Task { await displays.refreshFocus() }
    }

    /// Shows the deck as it is now, unsaved edits included.
    func present(fromSlide slide: Int, mode: ShowSession.Mode = .present) {
        guard show == nil else { return }
        session.endInteractions()
        let show = ShowSession(deck: session.document, startSlide: slide, mode: mode, displays: displays)
        show.onOpenDisplays = { [weak self] in self?.showDisplays(nil) }
        show.onEnd = { [weak self] lastSlide in
            guard let self else { return }
            self.show = nil
            self.session.showSlide(lastSlide)
            self.session.setPlayingLive(self.session.isPlayingLive)
            self.window?.makeKeyAndOrderFront(nil)
        }
        self.show = show
        session.canvas.setPaused(true) // Only the show animates while presenting.
        show.start()
    }

    /// Esc while the page has focus (trying out an embed): stop and deselect.
    override func cancelOperation(_ sender: Any?) {
        session.clearSelection()
    }

    func windowWillClose(_ notification: Notification) {
        show?.end()
        thumbnails.close()
        onClose?()
    }
}
