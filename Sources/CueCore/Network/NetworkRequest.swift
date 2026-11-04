import Foundation

/// One thing to ask the user: "This deck loads fonts from
/// fonts.googleapis.com and fonts.gstatic.com. Allow?"
public struct NetworkRequest: Sendable, Equatable {
    /// Hosts to allow if the user says yes, sorted.
    public var hosts: [String]
    /// What the deck uses them for, most important first.
    public var kinds: [RemoteResourceKind]

    public var message: String {
        let what = Self.list(kinds.map(\.noun))
        return "This deck loads \(what) from \(Self.list(hosts))."
    }

    /// Groups what a deck wants into one request, leaving out hosts already
    /// allowed or turned down, and hosts only named in its policy.
    public static func pending(
        from resources: [RemoteResource],
        allowed: [String],
        denied: [String]
    ) -> NetworkRequest? {
        let settled = Set((allowed + denied).map { $0.lowercased() })
        let wanted = resources.filter { $0.origin.isEvidenceOfUse && !settled.contains($0.host) }
        guard !wanted.isEmpty else { return nil }
        return NetworkRequest(
            hosts: Array(Set(wanted.map(\.host))).sorted(),
            kinds: Array(Set(wanted.map(\.kind))).sorted()
        )
    }

    /// "a", "a and b", "a, b and c".
    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }
}
