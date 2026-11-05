import AppKit
import CueCore
import WebKit

/// One surface that shows the real deck: the stage, the presenter's current
/// or next slide, an editor canvas, a thumbnail. Each owns one WKWebView.
///
/// Swift is the source of truth: call `show(_:finished:)` and the page
/// follows. Events from the page (ready, auto-builds, passthrough position)
/// arrive through `onEvent`.
@MainActor
public final class SlideRenderer: NSView {
    public let surface: SurfaceKind
    public var onEvent: ((BridgeEvent) -> Void)?
    /// Blocked hosts, refusals and hung scripts. Presenting code can ignore it.
    public var onSandboxEvent: ((SandboxEvent) -> Void)?
    /// False after the deck's scripts hung this surface; Cue's player still runs.
    public private(set) var deckScriptsEnabled = true
    /// How quickly a hung deck is noticed. Tests shorten it.
    var watchdogInterval: Duration = .seconds(3)
    public private(set) var isReady = false
    public private(set) var slideCount = 0
    /// When set, every load tags the live DOM with these source ids (editor
    /// surfaces). See `SlideRenderer+Editing.swift`.
    public var sourceManifest: [LiveElement]?
    public internal(set) var lastMapping: LiveMappingReport?

    /// Internal for the extensions in this module (zoom snapshots).
    var webView: WKWebView?
    private let messages = BridgeMessageHandler()
    private let policy = SandboxPolicy()
    private let watchdog = ScriptWatchdog()
    private let cover = NSView()
    private(set) var source: DeckSource?
    private(set) var position = ShowPosition.start
    private var finished = false
    private var paused = false
    /// True while paused; embeds show frozen stills (`SlideRenderer+Freeze`).
    var isPausedForEditing: Bool { paused }

    public init(surface: SurfaceKind) {
        self.surface = surface
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        cover.wantsLayer = true
        cover.isHidden = true
        messages.onEvent = { [weak self] event in self?.handle(event) }
        policy.onContentProcessTerminated = { [weak self] in self?.reload() }
        messages.onSandboxEvent = { [weak self] event in self?.onSandboxEvent?(event) }
        policy.onRefusal = { [weak self] refusal in self?.onSandboxEvent?(.refused(refusal)) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("SlideRenderer is created in code") }

    // MARK: Loading

    /// Loads (or reloads) a deck. Shows `position` once the page is ready.
    public func load(_ source: DeckSource, at position: ShowPosition = .start) async throws {
        self.source = source
        self.position = position
        isReady = false
        let rules = try await NetworkRules.compile(allowedHosts: source.allowedHosts)
        policy.rules = SandboxRules(
            pageURL: source.pageURL, allowedHosts: source.allowedHosts, permissions: source.permissions
        )
        let webView = WebViewFactory.make(
            source: source, surface: surface, rules: rules, messages: messages, policy: policy,
            deckScriptsEnabled: deckScriptsEnabled
        )
        install(webView)
        webView.load(URLRequest(url: source.pageURL))
        if deckScriptsEnabled && !paused { watchForHangs(webView) } // Paused pages start watching on resume.
    }

    /// A deck that locks up its page gets reloaded once with its own scripts
    /// off, so the show goes on with Cue's player and the deck's static content.
    private func watchForHangs(_ webView: WKWebView) {
        watchdog.interval = watchdogInterval
        watchdog.start(webView) { [weak self] in
            guard let self, self.deckScriptsEnabled else { return }
            self.deckScriptsEnabled = false
            self.isReady = false // The hung page can't answer; wait for the reloaded one.
            self.onSandboxEvent?(.scriptsStopped)
            self.reload()
        }
    }

    private func install(_ newWebView: WKWebView) {
        webView?.removeFromSuperview()
        webView = newWebView
        newWebView.frame = bounds
        newWebView.autoresizingMask = [.width, .height]
        newWebView.alphaValue = 0 // Revealed on `ready`, so the stacked, unstyled page never flashes.
        addSubview(newWebView, positioned: .below, relativeTo: nil)
        cover.frame = bounds
        cover.autoresizingMask = [.width, .height]
        addSubview(cover)
    }

    private func reload() {
        guard let source else { return }
        Task { try? await load(source, at: position) }
    }

    // MARK: Commands

    public func show(_ position: ShowPosition, finished: Bool = false) {
        self.position = position
        self.finished = finished
        guard isReady else { return } // Applied on ready.
        send(.show(position, finished: finished))
        if paused { // The new slide's embeds start live; freeze them once they've drawn.
            Task {
                try? await Task.sleep(for: Self.freezeDelay)
                if self.paused { await self.freezeEmbeds() }
            }
        }
    }

    public func setCover(black: Bool = false, white: Bool = false) {
        let state: ScreenCover = black ? .black : (white ? .white : .none)
        cover.layer?.backgroundColor = state.color?.cgColor
        cover.isHidden = state == .none
    }

    /// Pauses Web Animations and media in the page. Scripts with their own
    /// requestAnimationFrame loops keep running.
    public func setPaused(_ paused: Bool) {
        let changed = paused != self.paused
        self.paused = paused
        guard let webView, isReady else { return }
        send(.setPaused(paused))
        webView.setAllMediaPlaybackSuspended(paused)
        guard changed else { return }
        // A paused page isn't watched for hangs: one ping fewer every few seconds.
        if paused { watchdog.stop() } else if deckScriptsEnabled { watchForHangs(webView) }
        Task { paused ? await freezeEmbeds() : await thawEmbeds() }
    }

    /// A picture of the surface as rendered right now, cover included.
    public func snapshot() async throws -> NSImage {
        guard let webView, isReady else { throw SlideRendererError.notReady }
        if !cover.isHidden, let color = cover.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)) {
            return NSImage(size: bounds.size, flipped: false) { rect in
                color.setFill()
                rect.fill()
                return true
            }
        }
        return try await webView.takeSnapshot(configuration: nil)
    }

    /// Runs a function body in the bridge world. For tests and diagnostics.
    public func evaluateInBridge(_ functionBody: String) async throws -> Any? {
        guard let webView else { return nil }
        return try await webView.callAsyncJavaScript(functionBody, contentWorld: BridgeScript.world)
    }

    /// Runs a function body with arguments in the bridge world.
    func callInBridge(_ functionBody: String, arguments: [String: Any] = [:]) async throws -> Any? {
        guard let webView else { throw SlideRendererError.notReady }
        return try await webView.callAsyncJavaScript(
            functionBody, arguments: arguments, contentWorld: BridgeScript.world
        )
    }

    /// Runs a function body in the deck's own world, as a deck script would. Tests only.
    func evaluateInPage(_ functionBody: String) async throws -> Any? {
        guard let webView else { return nil }
        return try await webView.callAsyncJavaScript(functionBody, contentWorld: .page)
    }

    func send(_ command: BridgeCommand) {
        guard let webView else { return }
        let js = "window.__cue.receive(\(JSONText.string(command.wireMessage)))"
        webView.evaluateJavaScript(js, in: nil, in: BridgeScript.world) { _ in }
    }

    // MARK: Events

    private func handle(_ event: BridgeEvent) {
        if case .ready(let count) = event {
            isReady = true
            slideCount = count
            if paused { // A reload while paused: pause the page again and freeze its embeds once drawn.
                send(.setPaused(true))
                webView?.setAllMediaPlaybackSuspended(true)
            }
            show(position, finished: finished)
            webView?.alphaValue = 1
            if let sourceManifest {
                Task {
                    lastMapping = try? await mapSourceElements(sourceManifest)
                    onEvent?(event)
                }
                return
            }
        }
        onEvent?(event)
    }
}
