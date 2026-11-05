// cue-mcp: the helper Claude Code or Claude Desktop starts for Cue.
//
// It connects to the running Cue app's Unix-domain socket and pipes bytes
// both ways: stdin → Cue, Cue → stdout. MCP messages are newline-delimited
// JSON on both sides, so nothing is parsed here. Exits when either side
// closes. If Cue isn't running it opens it in the background and retries for
// a few seconds; then it explains on stderr (never on stdout, which belongs
// to the MCP protocol).
//
//   cue-mcp [--socket <path>]      (default ~/Library/Application Support/Cue/mcp.sock)
//   CUE_MCP_SOCKET=<path> cue-mcp
import Darwin
import Foundation

let arguments = CommandLine.arguments
func option(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

if arguments.contains("--help") {
    FileHandle.standardError.write(Data("usage: cue-mcp [--socket <path>]\nConnects Claude to the Cue app over MCP.\n".utf8))
    exit(0)
}

let socketPath = option("--socket") ?? ProcessInfo.processInfo.environment["CUE_MCP_SOCKET"]
    ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "Cue/mcp.sock").path

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("cue-mcp: \(message)\n".utf8))
    exit(1)
}

func connectSocket(_ path: String) -> Int32? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { fail("socket path is too long: \(path)") }
    withUnsafeMutableBytes(of: &address.sun_path) { buffer in
        _ = path.withCString { strncpy(buffer.baseAddress!.assumingMemoryBound(to: CChar.self), $0, buffer.count - 1) }
    }
    let connected = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    if connected == 0 { return fd }
    close(fd)
    return nil
}

/// Connects, starting Cue in the background (no window jumps forward) if needed.
func connectToCue() -> Int32 {
    if let fd = connectSocket(socketPath) { return fd }
    if option("--socket") == nil, ProcessInfo.processInfo.environment["CUE_MCP_SOCKET"] == nil {
        let open = Process()
        open.executableURL = URL(filePath: "/usr/bin/open")
        open.arguments = ["-g", "-b", "app.cue.Cue"]
        try? open.run()
        open.waitUntilExit()
    }
    for _ in 0..<20 {
        usleep(250_000)
        if let fd = connectSocket(socketPath) { return fd }
    }
    fail("Cue isn't running, or it isn't accepting Claude yet. Open Cue (Settings › Claude shows the status) and try again.")
}

/// Copies everything from `input` to `output` until `input` closes.
func pump(from input: Int32, to output: Int32) {
    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    while true {
        let count = read(input, &buffer, buffer.count)
        if count <= 0 { return }
        var written = 0
        while written < count {
            let result = buffer.withUnsafeBytes { write(output, $0.baseAddress! + written, count - written) }
            if result <= 0 { return }
            written += result
        }
    }
}

signal(SIGPIPE, SIG_IGN) // A closed side ends the pump; it isn't a crash.
let fd = connectToCue()
let toCue = Thread {
    pump(from: STDIN_FILENO, to: fd)
    // Claude closed stdin, so it has gone: nothing is left to deliver.
    shutdown(fd, SHUT_RDWR)
    exit(0)
}
toCue.start()
pump(from: fd, to: STDOUT_FILENO) // Cue closed the socket (quit): end too.
exit(0)
