import Foundation

/// Which MCP clients may edit decks. The first time a client connects Cue
/// asks the user; the answer is remembered by client name.
public final class ClientApproval: @unchecked Sendable {
    public enum Decision: String, Sendable, Codable { case approved, denied, pending }

    private let defaults: UserDefaults
    private let lock = NSLock()
    static let approvedKey = "cue.mcp.approvedClients"
    static let deniedKey = "cue.mcp.deniedClients"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func decision(for client: String) -> Decision {
        lock.withLock {
            if names(Self.approvedKey).contains(client) { return .approved }
            if names(Self.deniedKey).contains(client) { return .denied }
            return .pending
        }
    }

    public func set(_ decision: Decision, for client: String) {
        lock.withLock {
            var approved = names(Self.approvedKey), denied = names(Self.deniedKey)
            approved.remove(client)
            denied.remove(client)
            if decision == .approved { approved.insert(client) }
            if decision == .denied { denied.insert(client) }
            defaults.set(approved.sorted(), forKey: Self.approvedKey)
            defaults.set(denied.sorted(), forKey: Self.deniedKey)
        }
    }

    /// Every client with a remembered answer, for Settings › Claude.
    public var remembered: [(client: String, decision: Decision)] {
        lock.withLock {
            names(Self.approvedKey).map { ($0, Decision.approved) } + names(Self.deniedKey).map { ($0, Decision.denied) }
        }.sorted { $0.client < $1.client }
    }

    private func names(_ key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }
}
