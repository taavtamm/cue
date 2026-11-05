// cue-mcp: the helper Claude Code or Claude Desktop starts for Cue.
//
// It relays newline-delimited MCP messages between Claude (stdin/stdout)
// and the running Cue app's Unix-domain socket. If Cue isn't running when
// Claude starts it, it opens Cue in the background and waits a few seconds.
//
// Cue restarting (a new build, a quit and reopen) doesn't break Claude's
// session: the relay reconnects on its own and replays Claude's opening
// handshake, so Cue knows the client again, without passing Cue's second
// handshake reply back. While Cue is away, requests are answered at once
// with an error saying so. The relay only exits when Claude closes stdin.
// Messages to Claude only ever go to stdout; diagnostics go to stderr.
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

let explicitSocket = option("--socket") ?? ProcessInfo.processInfo.environment["CUE_MCP_SOCKET"]
let socketPath = explicitSocket ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appending(path: "Cue/mcp.sock").path

func note(_ message: String) {
    FileHandle.standardError.write(Data("cue-mcp: \(message)\n".utf8))
}

signal(SIGPIPE, SIG_IGN) // A closed side shows up as a failed write, not a crash.

let relay = Relay(socketPath: socketPath)
if !relay.connect(startingCue: explicitSocket == nil) {
    note("Cue isn't running yet. Open Cue (Settings › Claude shows the status); calls will work once it's open.")
}
relay.run()
