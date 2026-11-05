import Foundation
import MCP
import Network

/// Listens on Cue's Unix-domain socket and serves each connection with
/// `CueMCPServer`. Local only: the socket's folder is private to the user
/// (0700) and the socket itself is 0600, so other accounts can't connect.
public final class MCPSocketListener: @unchecked Sendable {
    public enum State: Sendable, Equatable { case stopped, listening(String), failed(String) }

    public let path: String
    private let server: CueMCPServer
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "cue.mcp.listener")
    private var onState: (@Sendable (State) -> Void)?

    public init(server: CueMCPServer, path: String = MCPSocket.defaultPath) {
        self.server = server
        self.path = path
    }

    public func start(onState: @escaping @Sendable (State) -> Void = { _ in }) throws {
        self.onState = onState
        let folder = URL(filePath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        if FileManager.default.fileExists(atPath: path) {
            guard !MCPSocket.isLive(path) else {
                let state = State.failed("Another copy of Cue is already serving Claude.")
                onState(state)
                return
            }
            try FileManager.default.removeItem(atPath: path) // Left over from a Cue that quit.
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: path)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.stateUpdateHandler = { [weak self] state in self?.update(state) }
        self.listener = listener
        listener.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        try? FileManager.default.removeItem(atPath: path)
        onState?(.stopped)
    }

    private func update(_ state: NWListener.State) {
        switch state {
        case .ready:
            chmod(path, 0o600)
            onState?(.listening(path))
        case .failed(let error):
            onState?(.failed(error.localizedDescription))
        case .cancelled:
            onState?(.stopped)
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        // Heartbeats would reach Claude as stray bytes through the stdio helper.
        let transport = NetworkTransport(connection: connection, heartbeatConfig: .disabled,
                                         reconnectionConfig: .disabled)
        let server = server
        Task { try? await server.serve(transport) }
    }
}
