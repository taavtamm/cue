import CueMCP
import Foundation
import MCP

/// An MCP client talking to Cue's server over the SDK's in-memory transport.
struct MCPHarness {
    let client: Client
    let host: FakeHost
    let server: CueMCPServer

    static func connect(_ host: FakeHost, name: String = "claude-code") async throws -> MCPHarness {
        let server = CueMCPServer(host: host)
        let (clientSide, serverSide) = await InMemoryTransport.createConnectedPair()
        Task { try await server.serve(serverSide) }
        let client = Client(name: name, version: "1.0")
        _ = try await client.connect(transport: clientSide)
        return MCPHarness(client: client, host: host, server: server)
    }

    /// Calls a tool and returns its text and error flag.
    func call(_ name: String, _ arguments: [String: Value] = [:]) async throws -> (text: String, isError: Bool) {
        let (content, isError) = try await client.callTool(name: name, arguments: arguments)
        let text = content.compactMap { if case .text(let text, _, _) = $0 { text } else { nil } }.joined()
        return (text, isError == true)
    }

    /// The change-set id in a write tool's JSON reply.
    static func changeID(_ text: String) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return nil }
        return object["id"] as? String
    }
}
