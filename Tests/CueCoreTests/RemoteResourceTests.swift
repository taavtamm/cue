import Foundation
import Testing
@testable import CueCore

@Suite("Finding the hosts a deck loads from")
struct RemoteResourceTests {
    static let deck = """
        <!doctype html><html><head>
        <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; font-src data: https://cdn.only-in-policy.com; img-src 'self'">
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">
        <link rel="icon" href="https://icons.example.com/i.png">
        <script src="https://cdn.example.com/lib.js"></script>
        <style>
          @import url("https://styles.example.com/base.css");
          @font-face { font-family: X; src: url(https://fonts.gstatic.com/s/x.woff2) format("woff2"); }
          .hero { background: url('https://images.example.com/bg.jpg'); }
          .local { background: url(img/local.png); }
        </style>
        </head><body>
        <img src="//protocol-relative.example.com/a.png" srcset="https://srcset.example.com/a@2x.png 2x">
        <div style="background-image:url(https://inline.example.com/x.png)"></div>
        <video src="https://video.example.com/v.mp4"></video>
        <iframe src="https://embed.example.com/"></iframe>
        <a href="https://links-dont-load.example.com/">link</a>
        <img src="data:image/png;base64,AAAA"><img src="local/b.png">
        </body></html>
        """

    private func scan(_ html: String) throws -> [RemoteResource] {
        RemoteResourceScanner.scan(root: try HTMLParser().parse(html), source: html)
    }

    @Test func findsEveryKindOfReference() throws {
        let found = Set(try scan(Self.deck).map { "\($0.host) \($0.kind.rawValue) \($0.origin.rawValue)" })
        let expected: Set<String> = [
            "cdn.only-in-policy.com fonts policy",
            "fonts.googleapis.com fonts markup",
            "icons.example.com images markup",
            "cdn.example.com scripts markup",
            "styles.example.com styles stylesheet",
            "fonts.gstatic.com fonts stylesheet",
            "images.example.com images stylesheet",
            "protocol-relative.example.com images markup",
            "srcset.example.com images markup",
            "inline.example.com images stylesheet",
            "video.example.com media markup",
            "embed.example.com frames markup",
        ]
        #expect(found == expected)
    }

    @Test func ignoresLocalAndInlineData() throws {
        let hosts = try scan(Self.deck).map(\.host)
        #expect(!hosts.contains { $0.contains("links-dont-load") })
        #expect(try scan("<html><body><img src='a.png'><img src='data:x'></body></html>").isEmpty)
    }

    @Test func groupsFontHostsIntoOneQuestion() throws {
        let html = """
            <html><head><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">
            <style>@font-face{src:url(https://fonts.gstatic.com/a.woff2)}</style></head><body></body></html>
            """
        let request = try #require(NetworkRequest.pending(from: try scan(html), allowed: [], denied: []))
        #expect(request.hosts == ["fonts.googleapis.com", "fonts.gstatic.com"])
        #expect(request.message == "This deck loads fonts from fonts.googleapis.com and fonts.gstatic.com.")
    }

    @Test func settledAndPolicyOnlyHostsAreNotAskedAgain() throws {
        let resources = try scan(Self.deck)
        let allHosts = Set(resources.map(\.host))
        let request = NetworkRequest.pending(
            from: resources, allowed: ["cdn.example.com"], denied: ["video.example.com"]
        )
        let hosts = try #require(request).hosts
        #expect(!hosts.contains("cdn.example.com"))
        #expect(!hosts.contains("video.example.com"))
        #expect(!hosts.contains("cdn.only-in-policy.com"))
        #expect(hosts.count == allHosts.count - 3)
        #expect(NetworkRequest.pending(from: [], allowed: [], denied: []) == nil)
    }

    @Test func demoDeckNeedsNoNetwork() throws {
        // Its fonts are embedded; Google Fonts appears only in its CSP.
        let document = try DeckDocument(contentsOf: try Fixtures.copy("demo-deck.html"))
        #expect(document.remoteResources.allSatisfy { $0.origin == .policy })
        #expect(Set(document.remoteResources.map(\.host)) == ["fonts.googleapis.com", "fonts.gstatic.com"])
        #expect(NetworkRequest.pending(from: document.remoteResources, allowed: [], denied: []) == nil)
    }

    @Test func grantPermissionsDefaultToOffAndSurviveOldFiles() throws {
        let old = Data(#"{"allowedHosts":["fonts.gstatic.com"]}"#.utf8)
        let grants = try JSONDecoder().decode(DeckGrants.self, from: old)
        #expect(grants.allowedHosts == ["fonts.gstatic.com"])
        #expect(grants.permissions == .none)
        var changed = grants
        changed.permissions.camera = true
        let roundTrip = try JSONDecoder().decode(DeckGrants.self, from: JSONEncoder().encode(changed))
        #expect(roundTrip.permissions.camera && !roundTrip.permissions.microphone)
    }
}
