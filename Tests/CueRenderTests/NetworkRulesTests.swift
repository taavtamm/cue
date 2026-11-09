import Foundation
import Testing
@testable import CueRender

/// The content rules alone, without a web view: which URLs an allowed host lets through.
@Suite("Network rules")
struct NetworkRulesTests {
    @Test func userinfoCantPassForAnAllowedHost() throws {
        let rules = try RuleListEvaluator(json: NetworkRules.json(allowedHosts: ["fonts.gstatic.com"]))
        #expect(rules.allows("https://fonts.gstatic.com/a.woff2"))
        #expect(rules.allows("https://fonts.gstatic.com:8443/a.woff2"))
        #expect(rules.allows("https://fonts.gstatic.com"))
        #expect(!rules.allows("https://fonts.gstatic.com:x@evil.example/"))
        #expect(!rules.allows("https://fonts.gstatic.com:443@evil.example/"))
        #expect(!rules.allows("https://fonts.gstatic.com@evil.example/"))
        #expect(!rules.allows("https://user@fonts.gstatic.com/a.woff2"))
        #expect(!rules.allows("https://fonts.gstatic.com.evil.example/"))
        #expect(rules.allows("cue-deck://deck/a.png"))
        #expect(rules.allows("data:text/plain,hi"))
    }

    @Test func onlyBareHostsAreAllowedAndOnlyOverHTTPS() throws {
        let entries = [
            "http://localhost", "ws://fonts.gstatic.com", "evil.example/path", "a@b.example", "x.example:80", "",
        ]
        let rules = try RuleListEvaluator(json: NetworkRules.json(allowedHosts: entries))
        for url in ["http://localhost/", "https://localhost/", "ws://fonts.gstatic.com/", "https://fonts.gstatic.com/",
                    "https://evil.example/path", "https://b.example/", "https://x.example/", "http://x.example:80/"] {
            #expect(!rules.allows(url), "\(url)")
        }
        #expect(!NetworkRules.json(allowedHosts: entries).contains("http://"))
        #expect(NetworkRules.bareHost("Fonts.GStatic.com") == "fonts.gstatic.com")
    }

    @Test func plainHTTPOnlyThroughTheTestPath() throws {
        let rules = try RuleListEvaluator(
            json: NetworkRules.json(
                allowedHosts: [], insecureTestOrigins: ["http://localhost", "localhost", "https://x"]
            )
        )
        #expect(rules.allows("http://localhost:8080/a"))
        #expect(!rules.allows("https://localhost/a"))
        #expect(!rules.allows("https://x/"))
        #expect(!rules.allows("http://localhost:1@127.0.0.1:8080/a"))
    }

    @Test func framesFromUserinfoURLsAreRefused() throws {
        let rules = SandboxRules(
            pageURL: URL(string: "cue-deck://deck/deck.html")!, allowedHosts: ["fonts.gstatic.com"], permissions: .none
        )
        #expect(rules.allowsSubframe(URL(string: "https://fonts.gstatic.com/embed")!))
        #expect(!rules.allowsSubframe(URL(string: "https://u:p@fonts.gstatic.com/embed")!))
        #expect(!rules.allowsSubframe(URL(string: "https://fonts.gstatic.com:x@evil.example/")!))
        #expect(!rules.allowsSubframe(URL(string: "http://fonts.gstatic.com/embed")!))
    }
}
