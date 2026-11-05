import Darwin
import Foundation

/// Where Cue's MCP socket lives, shared by the app and the `cue-mcp` helper
/// (which hard-codes the same path, so it needs no arguments).
public enum MCPSocket {
    /// `~/Library/Application Support/Cue/mcp.sock`
    public static var defaultPath: String {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appending(path: "Cue/mcp.sock").path
    }

    /// True when something is already listening at `path` (another Cue).
    static func isLive(_ path: String) -> Bool {
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        defer { close(socket) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { return false }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            _ = path.withCString { strncpy(buffer.baseAddress!.assumingMemoryBound(to: CChar.self), $0, buffer.count - 1) }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(socket, $0, size) == 0 }
        }
    }
}
