import AppKit
import CueCore
import CueRender

/// One show across every screen. `ShowController` is the source of truth;
/// `ShowBroadcaster` sends its position to every surface. Windows follow
/// display roles, and are added or removed when screens come and go,
/// without stopping the show.
@MainActor
final class ShowSession {
    enum Mode {
        /// Full screen on the screens given roles in Displays.
        case present
        /// On this Mac only: the stage and the presenter view in two windows.
        case rehearse
    }

    /// Called with the slide the show ended on.
    var onEnd: ((Int) -> Void)?
    var onOpenDisplays: (() -> Void)?

    let mode: Mode
    let controller: ShowController
    let model: PresenterModel
    private let deck: DeckDocument
    private let source: DeckSource
    private let displays: DisplayCoordinator
    private let focusState: FocusHint.StateProvider
    private let broadcaster: ShowBroadcaster
    private let keys = ShowKeyMap.standard
    private let cursor = CursorHider()
    private let displaySleep = DisplaySleepAssertion()
    /// Open surfaces keyed by display id (or a rehearsal slot name).
    private(set) var surfaces: [String: ShowSurface] = [:]
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    private var hasEnded = false

    init(
        deck: DeckDocument, startSlide: Int, mode: Mode, displays: DisplayCoordinator,
        focusState: @escaping FocusHint.StateProvider = FocusHint.systemState
    ) {
        self.deck = deck
        self.focusState = focusState
        self.mode = mode
        self.displays = displays
        source = DeckSource(document: deck)
        controller = ShowController(structure: deck.structure)
        controller.jump(toSlide: startSlide)
        broadcaster = ShowBroadcaster(stateCounts: controller.stateCounts)
        let sidecar = (try? CueSidecar.load(from: deck.sidecarURL)) ?? CueSidecar()
        let target = sidecar.targetDuration ?? ShowPace.defaultTarget(
            slideCount: deck.structure.slides.count, rehearsed: Array(sidecar.rehearsalTimings.values))
        model = PresenterModel(controller: controller, structure: deck.structure, targetDuration: target)
        model.renderingSummary = source.allowedHosts.isEmpty
            ? "Native HTML · offline"
            : "Native HTML · \(source.allowedHosts.count) host\(source.allowedHosts.count == 1 ? "" : "s") allowed"
        model.actions = makeActions()
    }

    // MARK: Start and end

    func start() {
        displaySleep.begin(reason: "Presenting \(deck.fileURL.lastPathComponent)")
        broadcaster.keepsAnimationsInSync = displays.keepsAnimationsInSync
        switch mode {
        case .present:
            savedPresentationOptions = NSApp.presentationOptions
            NSApp.presentationOptions = [.hideDock, .hideMenuBar]
            displays.isPresenting = true
            displays.onLayoutChange = { [weak self] in self?.applyDisplayRoles() }
            applyDisplayRoles()
            if surfaces.isEmpty { openRehearsalWindows() } // Every screen was Off: never strand the presenter.
        case .rehearse:
            openRehearsalWindows()
        }
        NSApp.activate()
        cursor.start()
        controller.startTimerIfNeeded()
        render()
        Task { [model, focusState] in model.showsFocusWarning = FocusHint.shouldWarn(await focusState()) }
        #if DEBUG
        Task { await ShowSnapshots.capture(session: self) { self.surfaces } }
        #endif
    }

    func end() {
        guard !hasEnded else { return }
        hasEnded = true
        cursor.stop()
        displaySleep.end()
        displays.onLayoutChange = nil
        displays.isPresenting = false
        surfaces.values.forEach(close)
        surfaces = [:]
        if mode == .present { NSApp.presentationOptions = savedPresentationOptions }
        onEnd?(controller.position.slide)
    }

    // MARK: Windows

    /// Opens, closes or replaces windows so each screen shows its current role.
    private func applyDisplayRoles() {
        let current = surfaces.mapValues(\.role)
        let change = DisplayLayoutChange(from: current, to: displays.roles)
        for id in change.close {
            if let surface = surfaces.removeValue(forKey: id) { close(surface) }
        }
        for (id, role) in change.open.sorted(by: { $0.key < $1.key }) {
            guard let screen = ScreenCatalog.screen(for: id) else { continue }
            open(role, in: .covering(screen), key: id)
        }
        updateScreenNames()
        render()
    }

    private func openRehearsalWindows() {
        let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        let stageWidth = area.width * 0.3
        let stageFrame = CGRect(x: area.minX + 20, y: area.maxY - stageWidth * 9 / 16 - 40,
                                width: stageWidth, height: stageWidth * 9 / 16 + 28)
        let presenterFrame = CGRect(x: stageFrame.maxX + 16, y: area.minY + 20,
                                    width: area.maxX - stageFrame.maxX - 36, height: area.height - 40)
        open(.stage, in: .rehearsal(title: "Stage — rehearsal", frame: stageFrame), key: "rehearse-stage")
        open(.presenter, in: .rehearsal(title: "Presenter view", frame: presenterFrame), key: "rehearse-presenter")
        surfaces["rehearse-presenter"]?.window.makeKeyAndOrderFront(nil)
        updateScreenNames()
    }

    private func open(_ role: DisplayRole, in window: ShowWindow, key: String) {
        guard let surface = ShowSurface.make(role: role, window: window, model: model) else { return }
        surfaces[key] = surface
        window.onShowKey = { [weak self] name in self?.handle(keyNamed: name) ?? false }
        window.onMouseMoved = { [weak self] in self?.cursor.noteMovement() }
        window.onClose = { [weak self] in self?.end() }
        for renderer in surface.renderers {
            broadcaster.add(renderer)
            renderer.onEvent = { [weak self, weak renderer] event in
                guard let renderer else { return }
                self?.handle(event, from: renderer)
            }
            Task {
                do {
                    try await renderer.load(source, at: controller.position)
                    render() // Stores each surface's position until its page is ready.
                } catch {
                    NSLog("Cue: a show surface failed to load: %@", error.localizedDescription)
                }
            }
        }
        window.makeKeyAndOrderFront(nil)
        if role == .presenter || role == .confidence { window.makeKey() }
    }

    private func close(_ surface: ShowSurface) {
        surface.renderers.forEach(broadcaster.remove)
        surface.window.onClose = nil
        surface.close()
    }

    private func updateScreenNames() {
        let name: (DisplayRole) -> String? = { role in
            guard let id = self.surfaces.first(where: { $0.value.role == role })?.key else { return nil }
            return self.displays.display(id)?.name ?? (self.mode == .rehearse ? "this Mac (window)" : nil)
        }
        model.stageName = name(.stage)
        model.confidenceName = name(.confidence)
    }

    // MARK: Input and output

    private func handle(keyNamed name: String) -> Bool {
        guard let key = keys.action(for: name) else { return false }
        controller.handle(key)
        render()
        return true
    }

    private func handle(_ event: BridgeEvent, from renderer: SlideRenderer) {
        switch event {
        case .position(let reported) where renderer.surface == .stage:
            controller.follow(reported) // Auto-builds, or the deck's own script in passthrough mode.
            render()
        case .ready where renderer.surface == .mirror || renderer.surface == .presenterCurrent:
            Task { [broadcaster] in
                try? await Task.sleep(for: .milliseconds(450))
                await broadcaster.alignNow() // A screen that joined mid-slide catches up.
            }
        case .liveContent(let slides) where renderer.surface == .stage:
            model.liveSlides = Set(slides)
        case .error(let message):
            NSLog("Cue bridge (%@): %@", renderer.surface.rawValue, message)
        default:
            break
        }
    }

    func render() {
        if controller.endRequested { return end() }
        broadcaster.broadcast(controller.position, black: controller.isBlack, white: controller.isWhite)
    }

    private func makeActions() -> PresenterActions {
        PresenterActions(
            next: { [weak self] in self?.perform { $0.next() } },
            previous: { [weak self] in self?.perform { $0.previous() } },
            jump: { [weak self] slide in self?.perform { $0.jump(toSlide: slide) } },
            toggleBlack: { [weak self] in self?.perform { $0.handle(.toggleBlack) } },
            toggleTimer: { [weak self] in self?.perform { $0.toggleTimer() } },
            end: { [weak self] in self?.end() },
            openDisplays: { [weak self] in self?.onOpenDisplays?() }
        )
    }

    private func perform(_ change: (ShowController) -> Void) {
        change(controller)
        render()
    }
}
