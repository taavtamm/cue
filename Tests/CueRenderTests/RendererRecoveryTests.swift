import CueCore
import Foundation
import Testing
import WebKit
@testable import CueRender

/// A surface keeps showing the right page through crashes, overlapping
/// loads, symlinked deck files and deck key handlers.
@Suite("Renderer recovery", .serialized)
@MainActor
struct RendererRecoveryTests {
    /// A store with nothing in it, so the user's own grants never leak into a test.
    static let noGrants = DeckGrantStore(
        fileURL: FileManager.default.temporaryDirectory.appending(path: "cue-no-grants-\(UUID().uuidString).json")
    )

    static func page(_ heading: String, head: String = "") -> String {
        """
        <!doctype html><html><head>\(head)</head><body>
        <section data-cue-slide id="a"><h1>\(heading)</h1></section></body></html>
        """
    }

    private func heading(_ harness: RendererHarness) async throws -> String {
        try await harness.evaluate("return document.querySelector('h1').textContent")
    }

    @Test func aSecondCrashTurnsDeckScriptsOffAndCrashesStopReloading() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        var stopped = 0
        harness.renderer.onSandboxEvent = { if $0 == .scriptsStopped { stopped += 1 } }
        try await harness.load(try Fixture.deck(html: Self.page("Crash")))

        harness.renderer.contentProcessTerminated(WKWebView()) // Some other page: ignored.
        #expect(harness.renderer.isReady)

        func crash() async throws {
            let current = try #require(harness.renderer.webView)
            harness.renderer.contentProcessTerminated(current)
            try await harness.waitUntil("reloaded") { harness.renderer.isReady && harness.renderer.webView !== current }
        }
        try await crash()
        #expect(harness.renderer.deckScriptsEnabled, "One crash only reloads")
        try await crash()
        #expect(!harness.renderer.deckScriptsEnabled)
        #expect(stopped == 1)
        for _ in 3...SlideRenderer.maxTerminations { try await crash() }

        let last = harness.renderer.webView
        harness.renderer.contentProcessTerminated(try #require(last))
        try await Task.sleep(for: .milliseconds(300))
        #expect(harness.renderer.webView === last, "Crashing past the limit no longer reloads")
        #expect(stopped == 1)
    }

    @Test func aSlowerEarlierLoadDoesntReplaceANewerOne() async throws {
        let harness = RendererHarness()
        defer { harness.close() }
        var older = try Fixture.deck(html: Self.page("Older"))
        older.allowedHosts = ["\(UUID().uuidString.lowercased()).example"] // New rule list: compiles slowly.
        let newer = try Fixture.deck(html: Self.page("Newer"))
        _ = try await NetworkRules.compile(allowedHosts: []) // Cached: the newer load compiles at once.

        let first = Task { try await harness.renderer.load(older) }
        let second = Task { try await harness.renderer.load(newer) }
        try await first.value
        try await second.value
        try await harness.waitUntil("ready") { harness.renderer.isReady }
        try await Task.sleep(for: .milliseconds(300))
        #expect(try await heading(harness) == "Newer")
    }

    @Test func aSymlinkedDeckIsStillServedFromMemory() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let real = folder.appending(path: "real.html")
        try Data(Self.page("On disk").utf8).write(to: real)
        let link = folder.appending(path: "deck.html")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        var source = DeckSource(document: try DeckDocument(contentsOf: link), grants: Self.noGrants)
        source.sourceText = Self.page("Unsaved edit")
        let harness = RendererHarness()
        defer { harness.close() }
        try await harness.load(source)
        #expect(try await heading(harness) == "Unsaved edit")
    }

    @Test func deckKeyHandlersNeverSeeKeysWhileTextIsEdited() async throws {
        // The deck registers a capture listener on window as early as a deck can.
        let head = "<script>window.__deckKeys = 0;"
            + "window.addEventListener('keydown', () => { window.__deckKeys += 1; }, true);</script>"
        let html = Self.page("Edit me", head: head)
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-keys-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "deck.html")
        try Data(html.utf8).write(to: file)
        let document = try DeckDocument(contentsOf: file)
        let harness = RendererHarness(surface: .editor)
        defer { harness.close() }
        harness.renderer.sourceManifest = document.liveManifest
        try await harness.load(DeckSource(document: document, grants: Self.noGrants))
        try await harness.waitUntil("source mapped") { harness.renderer.lastMapping != nil }

        let id = try #require(document.liveManifest.first { $0.tag == "h1" }?.cueID)
        #expect(try await harness.renderer.beginTextEditing(cueID: id))
        let press = "document.activeElement.dispatchEvent(new KeyboardEvent('keydown', { key: 'a', bubbles: true }));"
            + "return window.__deckKeys;"
        let whileEditing = try await harness.renderer.evaluateInPage(press) as? Int
        #expect(whileEditing == 0)
        try await harness.renderer.endTextEditing(commit: false)
        let afterwards = try await harness.renderer.evaluateInPage(press) as? Int
        #expect(afterwards == 1)
    }
}
