import AppKit
import CueCore
import CueRender
import SwiftUI

/// A temporary deck window: the real slide, a summary bar, and Play.
/// The Editor milestone replaces it with the full editor.
@MainActor
final class DeckWindowController: NSWindowController, NSWindowDelegate {
    let deck: DeckDocument
    var onClose: (() -> Void)?

    private let model: DeckPreviewModel
    private let preview = SlideRenderer(surface: .editor)
    private var show: ShowWindowController?

    init(deck: DeckDocument) {
        self.deck = deck
        model = DeckPreviewModel(document: deck)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = model.title
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
        window.minSize = CGSize(width: 640, height: 420)
        window.setFrameAutosaveName("DeckWindow")
        super.init(window: window)
        window.delegate = self
        window.contentView = makeContent()
        if window.frame.origin == .zero { window.center() }
        loadPreview()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("DeckWindowController is created in code") }

    private func makeContent() -> NSView {
        let bar = NSHostingView(rootView: DeckBar(
            model: model,
            onPrevious: { [weak self] in self?.step(by: -1) },
            onNext: { [weak self] in self?.step(by: 1) },
            onPlay: { [weak self] in self?.present(fromSlide: self?.model.slide ?? 0) }
        ))
        let stack = NSStackView(views: [preview, bar])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 0, bottom: 0, right: 0)
        bar.setContentHuggingPriority(.required, for: .vertical)
        return stack
    }

    private func loadPreview() {
        preview.onEvent = { [weak self] event in
            if case .liveContent(let slides) = event { self?.model.noteLive(slides) }
        }
        Task {
            do {
                try await preview.load(DeckSource(document: deck), at: ShowPosition(slide: model.slide))
                preview.show(ShowPosition(slide: model.slide), finished: true)
            } catch {
                DeckOpener.reportFailure(opening: deck.fileURL, error: error)
            }
        }
    }

    private func step(by delta: Int) {
        model.select(model.slide + delta)
        preview.show(ShowPosition(slide: model.slide), finished: true)
    }

    // MARK: Showing

    @objc func playSlideshow(_ sender: Any?) { present(fromSlide: model.slide) }
    @objc func playFromStart(_ sender: Any?) { present(fromSlide: 0) }

    func present(fromSlide slide: Int) {
        guard show == nil else { return }
        let show = ShowWindowController(deck: deck, startSlide: slide)
        show.onEnd = { [weak self] lastSlide in
            guard let self else { return }
            self.show = nil
            self.model.select(lastSlide)
            self.preview.show(ShowPosition(slide: lastSlide), finished: true)
            self.preview.setPaused(false)
            self.window?.makeKeyAndOrderFront(nil)
        }
        self.show = show
        preview.setPaused(true) // Only the stage animates while presenting.
        show.start()
    }

    func windowWillClose(_ notification: Notification) {
        show?.end()
        onClose?()
    }
}
