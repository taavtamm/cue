import Foundation
import WebKit

/// Content rules that block every network load except the deck's own
/// folder, inline data, and hosts the user allowed for this deck.
public enum NetworkRules {
    /// The rule list as WebKit's JSON format. Pure, so tests can inspect it.
    ///
    /// `allowedHosts` are bare hosts ("fonts.gstatic.com", HTTPS only) or,
    /// for local test servers, an origin with its scheme ("http://localhost").
    public static func json(allowedHosts: [String]) -> String {
        // WebKit's rule regexes have no alternation, so each scheme gets its own rule.
        var rules: [[String: Any]] = [rule(urlFilter: ".*", action: "block")]
        for scheme in [DeckSchemeHandler.scheme, "data", "blob", "about"] {
            rules.append(rule(urlFilter: "^\(scheme):", action: "ignore-previous-rules"))
        }
        for allowed in allowedHosts.sorted() {
            let (scheme, host) = split(allowed)
            let escaped = NSRegularExpression.escapedPattern(for: host)
            rules.append(rule(urlFilter: "^\(scheme)://\(escaped)[:/]", action: "ignore-previous-rules"))
        }
        return JSONText.string(rules, sortedKeys: true, fallback: "[]")
    }

    /// True when `url` is on an allowed host, by the same rule WebKit applies.
    static func matches(_ url: URL, allowed: String) -> Bool {
        let (scheme, host) = split(allowed)
        return url.scheme?.lowercased() == scheme && url.host?.lowercased() == host
    }

    /// Compiles (or reuses) the rule list for this set of hosts.
    @MainActor
    public static func compile(allowedHosts: [String]) async throws -> WKContentRuleList {
        let encoded = json(allowedHosts: allowedHosts)
        let identifier = "cue-network-\(stableHash(encoded))"
        let store = WKContentRuleListStore.default()!
        if let existing = try? await store.contentRuleList(forIdentifier: identifier) {
            return existing
        }
        return try await store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: encoded)!
    }

    private static func split(_ allowed: String) -> (scheme: String, host: String) {
        let lower = allowed.lowercased()
        guard let range = lower.range(of: "://") else { return ("https", lower) }
        return (String(lower[..<range.lowerBound]), String(lower[range.upperBound...]))
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
