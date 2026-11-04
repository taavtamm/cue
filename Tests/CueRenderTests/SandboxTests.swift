import CueCore
import Foundation
import Testing
@testable import CueRender

/// Milestone 3: a hostile deck tries every escape it can; each must fail.
@Suite("Sandbox against a hostile deck", .serialized)
@MainActor
struct SandboxTests {
    static let allowedOutcomes: Set<String> = ["blocked", "observed-by-test", "control-ok"]

    @Test func everyHostileAttemptFails() async throws {
        let server = try LocalServer()
        defer { server.stop() }
        let setup = try HostileDeck.make(server: server)
        let harness = RendererHarness()
        defer { harness.close() }
        var sandbox: [SandboxEvent] = []
        harness.renderer.onSandboxEvent = { sandbox.append($0) }

        try await harness.load(setup.source)
        try await harness.waitUntilAsync("hostile deck finished", timeout: 60) {
            let done: String? = try? await harness.evaluate("return document.body.getAttribute('data-hostile-done')")
            return done == "1"
        }
        let rows: [[String]] = try await harness.evaluate("""
            return Array.from(document.querySelectorAll('#hostile-results li'))
              .map((li) => [li.dataset.attempt, li.dataset.outcome, li.textContent]);
            """)
        for row in rows { print("HOSTILE | \(row[0]) | \(row[1]) | \(row[2])") }

        #expect(rows.count >= 45)
        let leaked = rows.filter { !Self.allowedOutcomes.contains($0[1]) }.map { $0[0] }
        #expect(leaked.isEmpty, "Leaked: \(leaked)")
        #expect(rows.filter { $0[1] == "control-ok" }.count == 1, "The deck could still read its own folder")

        // Nothing reached the network, not even a TCP connection.
        try await Task.sleep(for: .milliseconds(500))
        print("HOSTILE | server | connections \(server.connections) | requests \(server.requests.map(\.line))")
        #expect(server.connections == 0)

        // The page is still the deck: no navigation got through.
        let href: String = try await harness.evaluate("return location.href")
        print("HOSTILE | href | \(href)")
        #expect(href.split(separator: "#").first.map(String.init) == setup.source.pageURL.absoluteString)

        // The bridge never heard the page, and Swift saw the refusals.
        #expect(!harness.events.contains(.ready(slideCount: 99)))
        #expect(harness.renderer.slideCount == 3)
        let refusals = sandbox.compactMap { if case .refused(let refusal) = $0 { refusal } else { nil } }
        print("HOSTILE | refusals | \(refusals)")
        #expect(refusals.contains { if case .download = $0 { true } else { false } })
        #expect(refusals.contains { if case .navigation(_, true) = $0 { true } else { false } })

        // Spoofed postMessage and keys didn't move the slide.
        let current: Int = try await harness.evaluate("return window.__cue.debug().current.slide")
        #expect(current == 0)
    }

    @Test func bridgeIgnoresThePagesPoisonedBuiltIns() async throws {
        let server = try LocalServer()
        defer { server.stop() }
        let setup = try HostileDeck.make(server: server)
        let harness = RendererHarness()
        defer { harness.close() }
        try await harness.load(setup.source)

        try await harness.show(ShowPosition(slide: 1))
        let visible: [String] = try await harness.evaluate("""
            return Array.from(document.querySelectorAll('[data-cue-slide]'))
              .filter((s) => getComputedStyle(s).display !== 'none').map((s) => s.id);
            """)
        #expect(visible == ["s2"])
        let pageHits = try await harness.renderer.evaluateInPage("return window.__hostile.poisonHits") as? Int
        #expect(pageHits == 0, "Cue's bridge called a built-in the page had poisoned")
    }

    @Test func hungDeckIsReloadedWithItsScriptsOff() async throws {
        let server = try LocalServer()
        defer { server.stop() }
        let setup = try HostileDeck.make(server: server, page: "hostile-hang.html")
        let harness = RendererHarness()
        defer { harness.close() }
        var stopped = false
        harness.renderer.onSandboxEvent = { if $0 == .scriptsStopped { stopped = true } }
        harness.renderer.watchdogInterval = .milliseconds(500)

        try await harness.load(setup.source)
        try await harness.waitUntil("watchdog noticed the hang", timeout: 20) { stopped }
        try await harness.waitUntil("reloaded", timeout: 20) { harness.renderer.isReady }
        #expect(!harness.renderer.deckScriptsEnabled)

        try await harness.show(ShowPosition(slide: 2))
        let state: [String: Any] = try await harness.evaluate("""
            const visible = Array.from(document.querySelectorAll('[data-cue-slide]'))
              .filter((s) => getComputedStyle(s).display !== 'none').map((s) => s.id);
            return { visible, ran: document.body.getAttribute('data-deck-script-ran') };
            """)
        #expect(state["visible"] as? [String] == ["h3"])
        #expect(state["ran"] is NSNull, "The deck's script ran again after Cue turned scripts off")
    }
}
