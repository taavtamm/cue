import CueCore
import Foundation
import Testing
@testable import CueMCP

/// The real path Claude uses: the `cue-mcp` helper on stdio, Cue's socket
/// listener, the MCP server. Headless: no windows.
@Suite("Socket and helper", .serialized)
struct SocketTests {
    /// Unix socket paths must be short (104 bytes), so not the long temp folders.
    private func socketPath() -> String { "/tmp/cue-test-\(UUID().uuidString.prefix(8)).sock" }

    /// The helper `swift build` put beside this test bundle, whatever the build folder.
    private var helper: URL {
        let arguments = CommandLine.arguments
        let bundle = arguments.firstIndex(of: "--test-bundle-path").map { arguments[$0 + 1] }
            ?? Bundle.allBundles.first { $0.bundleURL.pathExtension == "xctest" }?.bundlePath
        guard var folder = bundle.map({ URL(filePath: $0) }) else {
            return Decks.repoRoot.appending(path: ".build/debug/cue-mcp")
        }
        while folder.pathExtension != "xctest", folder.pathComponents.count > 1 { folder.deleteLastPathComponent() }
        return folder.deletingLastPathComponent().appending(path: "cue-mcp")
    }

    @Test func helperSpeaksMCPThroughTheSocket() async throws {
        try #require(FileManager.default.isExecutableFile(atPath: helper.path), "build cue-mcp first")
        let (document, _) = try Decks.document()
        let path = socketPath()
        let listener = try await startListener(document, at: path)
        defer { listener.stop() }
        let mode = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(mode == 0o600, "only this user may connect")

        let process = Process()
        process.executableURL = helper
        process.arguments = ["--socket", path]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        let initialize = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","#
            + #""capabilities":{},"clientInfo":{"name":"test","version":"1"}}}"#
        input.fileHandleForWriting.write(Data((initialize + "\n").utf8))
        let line = try await readLine(from: output.fileHandleForReading, timeout: 10)
        #expect(line.contains("\"serverInfo\"") && line.contains("\"cue\""), "\(line)")
        let list = #"{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}"#
        input.fileHandleForWriting.write(Data((#"{"jsonrpc":"2.0","method":"notifications/initialized"}"# + "\n" + list + "\n").utf8))
        let tools = try await readLine(from: output.fileHandleForReading, timeout: 10)
        #expect(tools.contains("edit_element"))
        try input.fileHandleForWriting.close() // Claude quits: the helper exits cleanly.
        let exited = Date().addingTimeInterval(5)
        while process.isRunning, Date() < exited { try await Task.sleep(for: .milliseconds(50)) }
        if process.isRunning { process.terminate() }
        #expect(!process.isRunning && process.terminationStatus == 0)
    }

    /// No Cue: the helper stays up and answers each request with an MCP error
    /// (stdout stays protocol-only), and exits cleanly when Claude does.
    @Test func helperAnswersWhenCueIsntRunning() async throws {
        try #require(FileManager.default.isExecutableFile(atPath: helper.path), "build cue-mcp first")
        let process = Process()
        process.executableURL = helper
        process.arguments = ["--socket", socketPath()] // An explicit socket: never opens the app.
        let input = Pipe(), errors = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardError = errors
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data((Self.initialize + "\n").utf8))
        let reply = try await readLine(from: output.fileHandleForReading, timeout: 10)
        #expect(reply.contains("\"error\"") && reply.contains("Cue isn't running"), "\(reply)")
        try input.fileHandleForWriting.close()
        let exited = Date().addingTimeInterval(5)
        while process.isRunning, Date() < exited { try await Task.sleep(for: .milliseconds(50)) }
        if process.isRunning { process.terminate() }
        #expect(process.terminationStatus == 0)
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(message.contains("Cue isn't running"))
    }

    /// Cue restarts (a new build) mid-session: the helper reconnects and
    /// replays the handshake, so Claude's next call just works.
    @Test func helperSurvivesCueRestarting() async throws {
        try #require(FileManager.default.isExecutableFile(atPath: helper.path), "build cue-mcp first")
        let (document, _) = try Decks.document()
        let path = socketPath()
        var listener = try await startListener(document, at: path)
        let process = Process()
        process.executableURL = helper
        process.arguments = ["--socket", path]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        defer { if process.isRunning { process.terminate() } }
        input.fileHandleForWriting.write(Data((Self.initialize + "\n" + Self.initialized + "\n").utf8))
        _ = try await readLine(from: output.fileHandleForReading, timeout: 10)

        listener.stop() // Cue quits…
        try await Task.sleep(for: .milliseconds(400))
        listener = try await startListener(document, at: path) // …and comes back.
        defer { listener.stop() }
        try await Task.sleep(for: .milliseconds(1_500)) // The helper retries twice a second.

        let list = #"{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}"#
        input.fileHandleForWriting.write(Data((list + "\n").utf8))
        let tools = try await readLine(from: output.fileHandleForReading, timeout: 10)
        #expect(tools.contains("edit_element"), "the next call works without a new handshake: \(tools)")
        #expect(!tools.contains("serverInfo"), "the replayed handshake's reply isn't passed to Claude")
        try input.fileHandleForWriting.close()
    }

    static let initialize = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","#
        + #""capabilities":{},"clientInfo":{"name":"test","version":"1"}}}"#
    static let initialized = #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#

    /// A listening listener, or an error after 10 s: a listener that never
    /// gets there must fail the test, not hang the whole run.
    private func startListener(_ document: DeckDocument, at path: String) async throws -> MCPSocketListener {
        let listener = MCPSocketListener(server: CueMCPServer(host: FakeHost(document)), path: path)
        switch try await firstState(of: listener) {
        case .listening: return listener
        case .failed(let message): listener.stop(); throw CueMCPError.invalid(message)
        case .stopped: throw CueMCPError.invalid("The listener stopped.")
        }
    }

    /// The listener's first state other than stopped, waiting up to 10 s.
    private func firstState(of listener: MCPSocketListener) async throws -> MCPSocketListener.State {
        let states = StateBox()
        try listener.start { states.set($0) }
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let state = states.value, state != .stopped { return state }
            try await Task.sleep(for: .milliseconds(20))
        }
        listener.stop()
        throw CueMCPError.invalid("The listener didn't start within 10 s.")
    }

    @Test func aSecondCueDoesntStealTheSocket() async throws {
        let (document, _) = try Decks.document()
        let path = socketPath()
        let first = try await startListener(document, at: path)
        defer { first.stop() }
        let second = MCPSocketListener(server: CueMCPServer(host: FakeHost(document)), path: path)
        #expect(try await firstState(of: second) == .failed("Another copy of Cue is already serving Claude."))
        second.stop()
        #expect(FileManager.default.fileExists(atPath: path), "quitting the second Cue leaves the first one's socket")
    }

    /// The next newline-terminated line on `handle`, or "" after `timeout`.
    private func readLine(from handle: FileHandle, timeout: TimeInterval) async throws -> String {
        let buffer = LineBuffer()
        handle.readabilityHandler = { handle in buffer.append(handle.availableData) }
        defer { handle.readabilityHandler = nil }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let line = buffer.takeLine() { return line }
            try await Task.sleep(for: .milliseconds(50))
        }
        return ""
    }
}

/// The last state a listener reported, from its callback queue.
final class StateBox: @unchecked Sendable {
    private var state: MCPSocketListener.State?
    private let lock = NSLock()
    var value: MCPSocketListener.State? { lock.withLock { state } }
    func set(_ new: MCPSocketListener.State) { lock.withLock { state = new } }
}

/// Bytes from a pipe, split into lines.
final class LineBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ more: Data) { lock.withLock { data.append(more) } }

    func takeLine() -> String? {
        lock.withLock {
            guard let end = data.firstIndex(of: UInt8(ascii: "\n")) else { return nil }
            let line = String(decoding: data[data.startIndex..<end], as: UTF8.self)
            data = Data(data[data.index(after: end)...])
            return line
        }
    }
}
