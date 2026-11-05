import Darwin
import Foundation

/// Relays MCP lines between Claude and Cue, surviving Cue restarts.
final class Relay: @unchecked Sendable {
    private let socketPath: String
    private let lock = NSLock()
    /// Replies reach Claude from two threads; one line at a time.
    private let output = NSLock()
    private var fd: Int32 = -1
    /// Claude's `initialize` request and `initialized` notification, replayed on reconnect.
    private var handshake: [Data] = []
    private var handshakeID: String?
    /// The replayed initialize's reply belongs to us, not to Claude.
    private var swallowReply: String?
    /// Requests sent to Cue that haven't been answered yet.
    private var inFlight: Set<String> = []

    init(socketPath: String) { self.socketPath = socketPath }

    /// Connects once, opening Cue in the background first if allowed. False if Cue isn't there.
    func connect(startingCue: Bool) -> Bool {
        if let socket = UnixSocket.connect(socketPath) { return adopt(socket) }
        if startingCue {
            let open = Process()
            open.executableURL = URL(filePath: "/usr/bin/open")
            open.arguments = ["-g", "-b", "app.cue.Cue"]
            try? open.run()
            open.waitUntilExit()
            for _ in 0..<20 {
                usleep(250_000)
                if let socket = UnixSocket.connect(socketPath) { return adopt(socket) }
            }
        }
        return false
    }

    /// Claude → Cue on a thread, Cue → Claude here. Never returns.
    func run() -> Never {
        Thread { self.readClaude() }.start()
        while true {
            let socket = lock.withLock { fd }
            if socket < 0 {
                usleep(500_000)
                reconnect()
                continue
            }
            for line in UnixSocket.lines(from: socket) { deliverToClaude(line) }
            dropConnection(socket) // Cue quit or restarted.
        }
    }

    // MARK: Claude → Cue

    private func readClaude() -> Never {
        for line in UnixSocket.lines(from: STDIN_FILENO) {
            let message = Message(line)
            lock.withLock {
                if message.method == "initialize" { handshake = [line]; handshakeID = message.id }
                if message.method == "notifications/initialized", handshake.count == 1 { handshake.append(line) }
                if let id = message.id, message.method != nil { inFlight.insert(id) }
            }
            if !sendToCue(line), let id = message.id, message.method != nil {
                answerUnavailable(id) // Cue isn't there: say so instead of hanging.
            }
        }
        exit(0) // Claude closed stdin: it has gone.
    }

    private func sendToCue(_ line: Data) -> Bool {
        let socket = lock.withLock { fd }
        guard socket >= 0, UnixSocket.write(line, to: socket) else { return false }
        return true
    }

    // MARK: Cue → Claude

    private func deliverToClaude(_ line: Data) {
        let message = Message(line)
        let swallow: Bool = lock.withLock {
            if let id = message.id, message.method == nil { inFlight.remove(id) }
            if let id = message.id, id == swallowReply { swallowReply = nil; return true }
            return false
        }
        if !swallow { output.withLock { _ = UnixSocket.write(line, to: STDOUT_FILENO) } }
    }

    private func answerUnavailable(_ id: String) {
        lock.withLock { _ = inFlight.remove(id) }
        let reply = #"{"jsonrpc":"2.0","id":\#(id),"error":{"code":-32000,"message":"Cue isn't running. Open Cue, then try again."}}"#
        output.withLock { _ = UnixSocket.write(Data((reply + "\n").utf8), to: STDOUT_FILENO) }
    }

    // MARK: Connections

    @discardableResult
    private func adopt(_ socket: Int32) -> Bool {
        lock.withLock { fd = socket }
        return true
    }

    private func dropConnection(_ socket: Int32) {
        let lost: Set<String> = lock.withLock {
            if fd == socket { fd = -1 }
            let pending = inFlight.subtracting(handshakeID.map { [$0] } ?? [])
            inFlight = []
            return pending
        }
        close(socket)
        lost.forEach(answerUnavailable) // Asked just as Cue went away: try again.
    }

    /// Back again after a restart: replay the handshake so Cue knows Claude.
    private func reconnect() {
        guard let socket = UnixSocket.connect(socketPath) else { return }
        let replay: [Data] = lock.withLock {
            swallowReply = handshakeID
            return handshake
        }
        for line in replay where !UnixSocket.write(line, to: socket) { close(socket); return }
        adopt(socket)
        note("reconnected to Cue")
    }
}
