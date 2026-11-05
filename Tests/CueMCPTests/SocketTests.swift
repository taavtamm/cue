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

    private var helper: URL { Decks.repoRoot.appending(path: ".build/mcp/debug/cue-mcp") }

    @Test func helperSpeaksMCPThroughTheSocket() async throws {
        try #require(FileManager.default.isExecutableFile(atPath: helper.path), "build cue-mcp first")
        let (document, _) = try Decks.document()
        let path = socketPath()
        let listener = MCPSocketListener(server: CueMCPServer(host: FakeHost(document)), path: path)
        let ready = AsyncStream<MCPSocketListener.State> { continuation in
            try? listener.start { continuation.yield($0) }
        }
        defer { listener.stop() }
        for await state in ready {
            if case .listening = state { break }
            if case .failed(let message) = state { Issue.record("listener failed: \(message)"); return }
        }
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

    @Test func helperExplainsWhenCueIsntRunning() throws {
        try #require(FileManager.default.isExecutableFile(atPath: helper.path), "build cue-mcp first")
        let process = Process()
        process.executableURL = helper
        process.arguments = ["--socket", socketPath()] // An explicit socket: never opens the app.
        let errors = Pipe(), output = Pipe()
        process.standardError = errors
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 1)
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(message.contains("Cue isn't running"))
        #expect(output.fileHandleForReading.readDataToEndOfFile().isEmpty, "stdout stays clean for MCP")
    }

    @Test func aSecondCueDoesntStealTheSocket() async throws {
        let (document, _) = try Decks.document()
        let path = socketPath()
        let first = MCPSocketListener(server: CueMCPServer(host: FakeHost(document)), path: path)
        let ready = AsyncStream<MCPSocketListener.State> { continuation in try? first.start { continuation.yield($0) } }
        defer { first.stop() }
        for await state in ready { if case .listening = state { break } }
        let second = MCPSocketListener(server: CueMCPServer(host: FakeHost(document)), path: path)
        let states = AsyncStream<MCPSocketListener.State> { continuation in try? second.start { continuation.yield($0) } }
        for await state in states {
            #expect(state == .failed("Another copy of Cue is already serving Claude."))
            break
        }
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
