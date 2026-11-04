import Foundation
import Network

/// A tiny HTTP server on 127.0.0.1 that records every connection and
/// request it gets. Sandbox tests point hostile decks at it: if the sandbox
/// holds, it sees nothing at all.
final class LocalServer: @unchecked Sendable {
    struct Request: Equatable {
        var line: String
        var host: String
    }

    private(set) var port: UInt16 = 0
    private let listener: NWListener
    private let queue = DispatchQueue(label: "cue.test.local-server")
    private let lock = NSLock()
    private var _connections = 0
    private var _requests: [Request] = []

    var connections: Int { lock.withLock { _connections } }
    var requests: [Request] { lock.withLock { _requests } }

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
        _ = ready.wait(timeout: .now() + 5)
        port = listener.port?.rawValue ?? 0
    }

    /// `http://127.0.0.1:<port>`
    var origin: String { "http://127.0.0.1:\(port)" }

    func stop() { listener.cancel() }

    private func accept(_ connection: NWConnection) {
        lock.withLock { _connections += 1 }
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            if let data, let text = String(data: data, encoding: .utf8) { self?.record(text) }
            let body = "LEAK"
            let response = "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Type: text/plain\r\n"
                + "Content-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }

    private func record(_ text: String) {
        let lines = text.components(separatedBy: "\r\n")
        let host = lines.first { $0.lowercased().hasPrefix("host:") }?.dropFirst(5).trimmingCharacters(in: .whitespaces)
        lock.withLock { _requests.append(Request(line: lines.first ?? "", host: host ?? "")) }
    }
}
