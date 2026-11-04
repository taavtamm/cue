import AppKit
import CueCore
@testable import CueRender

/// A SlideRenderer in an on-screen-sized window, with helpers to wait for
/// bridge events and to inspect the page from Cue's world.
@MainActor
final class RendererHarness {
    let renderer: SlideRenderer
    let window: NSWindow
    private(set) var events: [BridgeEvent] = []

    init(surface: SurfaceKind = .stage, size: CGSize = CGSize(width: 1280, height: 800)) {
        renderer = SlideRenderer(surface: surface)
        window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -4000, y: 0), size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.contentView = renderer
        window.orderFrontRegardless() // Rendering and animations run only for windows on screen.
        renderer.onEvent = { [weak self] event in self?.events.append(event) }
    }

    func load(_ source: DeckSource) async throws {
        try await renderer.load(source)
        try await waitUntil("page ready") { self.renderer.isReady }
    }

    func waitUntil(_ what: String, timeout: TimeInterval = 15, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw HarnessError.timedOut(what) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Runs `body` in the bridge world and returns its result as `T`.
    func evaluate<T>(_ body: String, as type: T.Type = T.self) async throws -> T {
        let value = try await renderer.evaluateInBridge(body)
        guard let typed = value as? T else { throw HarnessError.unexpected(String(describing: value)) }
        return typed
    }

    /// Shows a position and waits until the page has applied it.
    func show(_ position: ShowPosition, finished: Bool = false) async throws {
        renderer.show(position, finished: finished)
        let expected = position.slide
        try await waitUntilAsync("slide \(expected) shown") {
            let current: Int? = try? await self.evaluate("return window.__cue.debug().current.slide")
            return current == expected
        }
    }

    func waitUntilAsync(_ what: String, timeout: TimeInterval = 10, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !condition() {
            if Date() > deadline { throw HarnessError.timedOut(what) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    func close() {
        window.orderOut(nil)
    }
}

enum HarnessError: Error {
    case timedOut(String)
    case unexpected(String)
}
