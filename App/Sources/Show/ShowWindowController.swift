import AppKit
import CueCore
import CueRender

/// One show on one screen (multi-display arrives in milestone 2).
/// `ShowController` is the source of truth; this window turns key presses
/// into its actions and renders whatever position it holds.
@MainActor
final class ShowWindowController: NSWindowController {
    /// Called with the slide the show ended on.
    var onEnd: ((Int) -> Void)?

    private let deck: DeckDocument
    private let controller: ShowController
    private let stage = SlideRenderer(surface: .stage)
    private let keys = ShowKeyMap.standard
    private let cursor = CursorHider()
    private let displaySleep = DisplaySleepAssertion()
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    private var hasEnded = false

    init(deck: DeckDocument, startSlide: Int, screen: NSScreen? = NSScreen.main) {
        self.deck = deck
        controller = ShowController(structure: deck.structure)
        controller.jump(toSlide: startSlide)

        let frame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let window = ShowWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrame(frame, display: false)
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.fullScreenNone, .canJoinAllSpaces]
        window.contentView = stage
        super.init(window: window)

        window.onShowKey = { [weak self] name in self?.handle(keyNamed: name) ?? false }
        window.onMouseMoved = { [weak self] in self?.cursor.noteMovement() }
        stage.onEvent = { [weak self] event in self?.handle(event) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("ShowWindowController is created in code") }

    func start() {
        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        displaySleep.begin(reason: "Presenting \(deck.fileURL.lastPathComponent)")
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        cursor.start()
        controller.startTimerIfNeeded()
        Task {
            do {
                try await stage.load(DeckSource(document: deck), at: controller.position)
                #if DEBUG
                await ShowSnapshots.capture(stage: stage, controller: controller) { render() }
                #endif
            } catch {
                end()
                DeckOpener.reportFailure(opening: deck.fileURL, error: error)
            }
        }
    }

    func end() {
        guard !hasEnded else { return }
        hasEnded = true
        cursor.stop()
        displaySleep.end()
        NSApp.presentationOptions = savedPresentationOptions
        window?.orderOut(nil)
        onEnd?(controller.position.slide)
    }

    // MARK: Input and output

    private func handle(keyNamed name: String) -> Bool {
        guard let key = keys.action(for: name) else { return false }
        controller.handle(key)
        render()
        return true
    }

    private func handle(_ event: BridgeEvent) {
        switch event {
        case .position(let reported):
            // Auto-builds in Cue-driven decks, or the deck's own script in passthrough.
            controller.follow(reported)
            if deck.structure.renderMode == .cueDriven { render() }
        case .error(let message):
            NSLog("Cue bridge: %@", message)
        case .ready, .liveContent:
            break
        }
    }

    private func render() {
        if controller.endRequested { return end() }
        stage.setCover(black: controller.isBlack, white: controller.isWhite)
        stage.show(controller.position)
    }
}
