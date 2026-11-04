import Foundation
import WebKit

/// Content rules that block every network load except the deck's own
/// folder, inline data, and hosts the user allowed for this deck.
public enum NetworkRules {
    /// The rule list as WebKit's JSON format. Pure, so tests can inspect it.
    public static func json(allowedHosts: [String]) -> String {
        // WebKit's rule regexes have no alternation, so each scheme gets its own rule.
        var rules: [[String: Any]] = [rule(urlFilter: ".*", action: "block")]
        for scheme in [DeckSchemeHandler.scheme, "data", "blob", "about"] {
            rules.append(rule(urlFilter: "^\(scheme):", action: "ignore-previous-rules"))
        }
        for host in allowedHosts.sorted() {
            let escaped = NSRegularExpression.escapedPattern(for: host.lowercased())
            rules.append(rule(urlFilter: "^https://\(escaped)[:/]", action: "ignore-previous-rules"))
        }
        return JSONText.string(rules, sortedKeys: true, fallback: "[]")
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
