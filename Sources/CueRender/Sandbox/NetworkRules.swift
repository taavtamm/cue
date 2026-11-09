import Foundation
import WebKit

/// Content rules that block every network load except the deck's own
/// folder, inline data, and hosts the user allowed for this deck.
public enum NetworkRules {
    /// The rule list as WebKit's JSON format. Pure, so tests can inspect it.
    ///
    /// `allowedHosts` are bare host names ("fonts.gstatic.com"), allowed over
    /// HTTPS only. Anything else (a scheme, a path, userinfo) is ignored.
    public static func json(allowedHosts: [String]) -> String {
        json(allowedHosts: allowedHosts, insecureTestOrigins: [])
    }

    /// As above, plus plain-HTTP origins ("http://localhost") that only tests
    /// can pass, through `DeckSource.insecureTestOrigins`.
    static func json(allowedHosts: [String], insecureTestOrigins: [String]) -> String {
        // WebKit's rule regexes have no alternation, so each scheme gets its own rule.
        var rules: [[String: Any]] = [rule(urlFilter: ".*", action: "block")]
        for scheme in [DeckSchemeHandler.scheme, "data", "blob", "about"] {
            rules.append(rule(urlFilter: "^\(scheme):", action: "ignore-previous-rules"))
        }
        let origins = Set(allowedHosts.compactMap(bareHost).map { "https://" + $0 }
            + insecureTestOrigins.compactMap(testOrigin))
        for origin in origins.sorted() {
            guard let separator = origin.range(of: "://") else { continue }
            let host = NSRegularExpression.escapedPattern(for: String(origin[separator.upperBound...]))
            let prefix = "^" + origin[..<separator.upperBound] + host
            // The host must end the authority: a port, then the path (or nothing),
            // so "https://allowed.example:x@evil.example/" doesn't count as allowed.
            for tail in ["/", ":[0-9]+/", "$", ":[0-9]+$"] {
                rules.append(rule(urlFilter: prefix + tail, action: "ignore-previous-rules"))
            }
        }
        // Userinfo is never needed and only ever disguises a host: block it last, whatever matched before.
        rules.append(rule(urlFilter: "^[a-z-]+://[^/]*@", action: "block"))
        return JSONText.string(rules, sortedKeys: true, fallback: "[]")
    }

    /// True when `url` is on an allowed host, by the same rule WebKit applies.
    static func matches(_ url: URL, allowed: String) -> Bool {
        guard let host = bareHost(allowed), url.user == nil, url.password == nil else { return false }
        return url.scheme?.lowercased() == "https" && url.host?.lowercased() == host
    }

    /// Compiles (or reuses) the rule list for this set of hosts.
    @MainActor
    public static func compile(allowedHosts: [String]) async throws -> WKContentRuleList {
        try await compile(allowedHosts: allowedHosts, insecureTestOrigins: [])
    }

    @MainActor
    static func compile(allowedHosts: [String], insecureTestOrigins: [String]) async throws -> WKContentRuleList {
        let encoded = json(allowedHosts: allowedHosts, insecureTestOrigins: insecureTestOrigins)
        let identifier = "cue-network-\(stableHash(encoded))"
        let store = WKContentRuleListStore.default()!
        if let existing = try? await store.contentRuleList(forIdentifier: identifier) {
            return existing
        }
        return try await store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: encoded)!
    }

    /// The lowercased host when `text` is nothing but a DNS name or IPv4
    /// address; nil for "http://x", "x/path", "user@x", "x:443" and the like.
    static func bareHost(_ text: String) -> String? {
        let host = text.lowercased()
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard !host.isEmpty, host.allSatisfy(allowed.contains),
              let first = host.first, first != ".", first != "-"
        else { return nil }
        return host
    }

    /// `http://<bare host>`, lowercased, or nil. Tests only.
    private static func testOrigin(_ text: String) -> String? {
        let lower = text.lowercased()
        guard lower.hasPrefix("http://"), let host = bareHost(String(lower.dropFirst("http://".count))) else {
            return nil
        }
        return "http://" + host
    }

    private static func rule(urlFilter: String, action: String) -> [String: Any] {
        ["trigger": ["url-filter": urlFilter], "action": ["type": action]]
    }

    /// FNV-1a, so identifiers stay the same across launches (Swift's hashValue doesn't).
    private static func stableHash(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
