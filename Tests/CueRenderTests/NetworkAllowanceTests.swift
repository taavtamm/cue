import CueCore
import Foundation
import Testing
@testable import CueRender

/// Per-deck network allowance: an allowed host gets through, nothing else does.
@Suite("Per-deck network allowance", .serialized)
@MainActor
struct NetworkAllowanceTests {
    static func probeDeck(port: UInt16) -> String {
        """
        <!doctype html><html><body>
        <section data-cue-slide id="a"><h1>Fonts</h1></section>
        <script>
          const out = {};
          const probe = (name, url) =>
            fetch(url).then(() => { out[name] = 'loaded'; }, () => { out[name] = 'blocked'; });
          Promise.all([
            probe('allowed', 'http://localhost:\(port)/allowed.woff2'),
            probe('other', 'http://127.0.0.1:\(port)/other.woff2'),
          ]).then(() => document.body.setAttribute('data-result', 'allowed=' + out.allowed + ' other=' + out.other));
        </script></body></html>
        """
    }

    @Test func allowedHostGetsThroughAndNothingElse() async throws {
        let server = try LocalServer()
        defer { server.stop() }
        var source = try Fixture.deck(html: Self.probeDeck(port: server.port))
        source.allowedHosts = ["http://localhost"]
        let harness = RendererHarness()
        defer { harness.close() }
        try await harness.load(source)

        try await harness.waitUntilAsync("probes settled") {
            let result: String? = try? await harness.evaluate("return document.body.getAttribute('data-result')")
            return result != nil
        }
        let result: String = try await harness.evaluate("return document.body.getAttribute('data-result')")
        print("ALLOWANCE | \(result) | \(server.requests)")
        #expect(result == "allowed=loaded other=blocked")
        #expect(!server.requests.isEmpty)
        #expect(server.requests.allSatisfy { $0.host.hasPrefix("localhost") }, "\(server.requests)")
    }

    @Test func fontsHostRuleMatchesThatHostOnly() throws {
        let json = NetworkRules.json(allowedHosts: ["fonts.gstatic.com"])
        let rules = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        let filters = rules.compactMap { ($0["trigger"] as? [String: String])?["url-filter"] }
        let filter = try #require(filters.last)
        let regex = try NSRegularExpression(pattern: filter)
        func allows(_ url: String) -> Bool {
            regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
        }
        #expect(allows("https://fonts.gstatic.com/s/inter/v1/a.woff2"))
        #expect(!allows("https://fonts.gstatic.com.evil.example/a.woff2"))
        #expect(!allows("http://fonts.gstatic.com/a.woff2"))
        #expect(!allows("https://evil.example/?https://fonts.gstatic.com/"))
        #expect(!allows("https://fonts.googleapis.com/css2"))
    }

    @Test func pageReportsHostsItReachesForAtRuntime() async throws {
        let html = """
            <!doctype html><html><head><style>
            @font-face { font-family: Inter; src: url(https://fonts.gstatic.com/s/inter.woff2); }
            </style></head><body><section data-cue-slide id="a"><h1>Hi</h1></section>
            <script>setTimeout(() => {
              const img = document.createElement('img');
              img.src = 'https://dynamic.example.com/x.png';
              document.body.appendChild(img);
            }, 200);</script></body></html>
            """
        let source = try Fixture.deck(html: html)
        let harness = RendererHarness()
        defer { harness.close() }
        var reported: [RemoteResource] = []
        harness.renderer.onSandboxEvent = { if case .remoteResources(let found) = $0 { reported += found } }
        try await harness.load(source)
        try await harness.waitUntil("runtime report") { reported.contains { $0.host == "dynamic.example.com" } }

        #expect(reported.contains(RemoteResource(host: "dynamic.example.com", kind: .images, origin: .runtime)))
        #expect(reported.contains(RemoteResource(host: "fonts.gstatic.com", kind: .fonts, origin: .runtime)))
        let request = try #require(NetworkRequest.pending(from: reported, allowed: [], denied: []))
        #expect(request.message == "This deck loads fonts and images from dynamic.example.com and fonts.gstatic.com.")
    }
}
