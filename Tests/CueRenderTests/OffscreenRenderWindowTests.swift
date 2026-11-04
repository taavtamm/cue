import AppKit
import Testing
@testable import CueRender

/// The thumbnail window must never land on a screen, whatever moves it.
@Suite("Offscreen render window")
@MainActor
struct OffscreenRenderWindowTests {
    @Test func startsOffEveryScreen() {
        let window = OffscreenRenderWindow(size: CGSize(width: 384, height: 216))
        defer { window.close() }
        window.orderFrontRegardless()
        #expect(window.isOffAllScreens)
    }

    @Test func movesBackWhenSomethingMovesItOnScreen() throws {
        let window = OffscreenRenderWindow(size: CGSize(width: 384, height: 216))
        defer { window.close() }
        window.orderFrontRegardless()
        let screen = try #require(NSScreen.main)
        window.setFrameOrigin(CGPoint(x: screen.frame.minX + 40, y: screen.frame.minY + 40))
        #expect(window.isOffAllScreens)
    }

    @Test func screenChangesParkItAgain() {
        let window = OffscreenRenderWindow(size: CGSize(width: 384, height: 216))
        defer { window.close() }
        window.orderFrontRegardless()
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
        #expect(window.isOffAllScreens)
    }
}
