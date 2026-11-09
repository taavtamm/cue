import Foundation
import MCP

/// One client connected to Cue: who it is and whether it can sample (run a
/// model on Cue's behalf), which the Ask bar uses when available.
public struct MCPConnectionInfo: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let client: String
    public let supportsSampling: Bool
    public let connectedAt: Date
}

/// The clients connected right now, for Settings and the Ask bar.
public actor MCPConnections {
    private var servers: [UUID: Server] = [:]
    public private(set) var all: [MCPConnectionInfo] = []
    private var onChange: (@Sendable ([MCPConnectionInfo]) -> Void)?

    public init() {}

    public func observe(_ handler: @escaping @Sendable ([MCPConnectionInfo]) -> Void) {
        onChange = handler
        handler(all)
    }

    func add(_ info: MCPConnectionInfo, server: Server) {
        servers[info.id] = server
        all.removeAll { $0.id == info.id }
        all.append(info)
        onChange?(all)
    }

    func remove(_ id: UUID) {
        servers[id] = nil
        all.removeAll { $0.id == id }
        onChange?(all)
    }

    /// A connected client that can sample and that the user approved, for the Ask bar.
    public func samplingServer(host: DeckHost) async -> (server: Server, client: String)? {
        for info in all where info.supportsSampling {
            guard await host.approval(for: info.client) == .approved, let server = servers[info.id] else { continue }
            return (server, info.client)
        }
        return nil
    }
}
