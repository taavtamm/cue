import Foundation

/// Applies a WebKit content rule list (block and ignore-previous-rules only)
/// to a URL the way WebKit does: in order, so the last matching rule decides.
struct RuleListEvaluator {
    private let rules: [(regex: NSRegularExpression, blocks: Bool)]

    init(json: String) throws {
        let list = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]] ?? []
        rules = try list.map { rule in
            let filter = (rule["trigger"] as? [String: String])?["url-filter"] ?? ""
            let type = (rule["action"] as? [String: String])?["type"]
            return (try NSRegularExpression(pattern: filter), type == "block")
        }
    }

    /// True when `url` would load.
    func allows(_ url: String) -> Bool {
        var blocked = false
        for rule in rules where rule.regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil {
            blocked = rule.blocks
        }
        return !blocked
    }
}
