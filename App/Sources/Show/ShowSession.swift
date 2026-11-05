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
        /// On this Mac only: the presenter view alone, full screen.
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
    private let cursor = CursorHider(delay: .seconds(CueSettings.shared.cursorHideDelay))
    private let displaySleep = DisplaySleepAssertion()
    /// Open surfaces keyed by display id (or a rehearsal slot name).
    private(set) var surfaces: [String: ShowSurface] = [:]
    private var savedPresentationOptions: NSApplication.PresentationOptions = []
    private var hasEnded = false
    /// Showing the presenter view on the main screen because no screen shows it.
    private var usesFallbackPresenter = false

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
            slideCount: deck.structure.slides.count, rehearsed: Array(sidecar.rehearsalTimings.values),
            minutesPerSlide: CueSettings.shared.minutesPerSlide)
        model = PresenterModel(controller: controller, structure: deck.structure, targetDuration: target)
        model.renderingSummary = source.allowedHosts.isEmpty
            ? "Native HTML · offline"
            : "Native HTML · \(source.allowedHosts.count) host\(source.allowedHosts.count == 1 ? "" : "s") allowed"
        model.actions = makeActions()
    }

    // MARK: Start and end

    func start() {
        if CueSettings.shared.keepsDisplayAwake {
            displaySleep.begin(reason: "Presenting \(deck.fileURL.lastPathComponent)")
        }
        broadcaster.keepsAnimationsInSync = displays.keepsAnimationsInSync
        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        switch mode {
        case .present:
            displays.isPresenting = true
            displays.onLayoutChange = { [weak self] in self?.applyDisplayRoles() }
            applyDisplayRoles()
            if surfaces.isEmpty { openRehearsalView() } // Every screen was Off: never strand the presenter.
        case .rehearse:
            openRehearsalView()
        }
        NSApp.activate()
        cursor.start()
        controller.startTimerIfNeeded()
        render()
        if !model.isRehearsal { // No audience while rehearsing, so no notification risk.
            Task { [model, focusState] in model.showsFocusWarning = FocusHint.shouldWarn(await focusState()) }
        }
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
        NSApp.presentationOptions = savedPresentationOptions
        onEnd?(controller.position.slide)
    }

    // MARK: Windows

    /// Opens, closes or replaces windows so each screen shows its current role.
    private func applyDisplayRoles() {
        let target = FallbackPresenter.roles(displays.roles, mainID: Self.mainDisplayID, active: &usesFallbackPresenter)
        // With no audience screen the presenter view also runs the show (auto-builds);
        // when that changes, its window is rebuilt so only one surface leads.
        let rehearsing = target.stageID == nil && target.displays(with: .mirror).isEmpty
        if rehearsing != model.isRehearsal {
            model.isRehearsal = rehearsing
            for (id, surface) in surfaces where surface.role == .presenter {
                surfaces.removeValue(forKey: id)
                close(surface)
            }
        }
        let change = DisplayLayoutChange(from: surfaces.mapValues(\.role), to: target)
        for id in change.close {
            if let surface = surfaces.removeValue(forKey: id) { close(surface) }
        }
        for (id, role) in change.open.sorted(by: { $0.key < $1.key }) {
            guard let screen = ScreenCatalog.screen(for: id) else { continue }
            open(role, in: .covering(screen, for: role), key: id)
        }
        refitWindowsToScreens()
        updateScreenNames()
        render()
    }

    /// A screen that changed resolution or moved keeps its window covering it.
    private func refitWindowsToScreens() {
        for (id, surface) in surfaces {
            guard let screen = ScreenCatalog.screen(for: id), surface.window.frame != screen.frame else { continue }
            surface.window.setFrame(screen.frame, display: true)
        }
    }

    /// The screen with the menu bar, where the presenter view goes if no screen shows it.
    private static var mainDisplayID: String? { NSScreen.screens.first.map(ScreenCatalog.id(of:)) }

    /// Rehearsal is the presenter view alone, full screen on this Mac, like
    /// Keynote's: current slide, notes and what's next. No stage window.
    private func openRehearsalView() {
        model.isRehearsal = true
        model.showsFocusWarning = false
        let screen = NSScreen.main ?? NSScreen.screens[0]
        open(.presenter, in: .covering(screen, for: .presenter), key: "rehearse-presenter")
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
