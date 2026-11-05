import CueCore
import Foundation
import MCP

/// Cue's MCP server. Each connection (a Claude Code or Claude Desktop
/// session, through the `cue-mcp` helper) gets its own `Server` with Cue's
/// tools and resources over the same `DeckHost`.
public final class CueMCPServer: Sendable {
    public static let name = "cue"
    public static let version = "0.1"
    static let instructions = """
        Cue is a presentation app; these tools read and edit the deck the user has open in Cue. Slide numbers \
        are 1-based. Start with get_outline (and get_selection to see what the user is looking at). Every edit \
        is applied live and returns a change-set id; nothing is saved, and the user accepts or undoes each \
        change in Cue. Prefer small edits (edit_element) over replacing whole slides. Use render_slide to check \
        your work. To serve requests the user types into Cue's Ask bar, call next_request in a loop, do what \
        each request asks, then call complete_request with a one-line summary.
        """

    public let host: DeckHost
    public let connections = MCPConnections()

    public init(host: DeckHost) {
        self.host = host
    }

    /// Serves one connection until it closes.
    public func serve(_ transport: any Transport) async throws {
        let id = UUID()
        let client = ClientName()
        let server = Server(
            name: Self.name, version: Self.version, title: "Cue", instructions: Self.instructions,
            capabilities: .init(resources: .init(subscribe: false, listChanged: false), tools: .init(listChanged: false))
        )
        await register(on: server, client: client)
        try await server.start(transport: transport) { [connections] info, capabilities in
            await client.set(info.name)
            let connection = MCPConnectionInfo(id: id, client: info.name, supportsSampling: capabilities.sampling != nil,
                                               connectedAt: Date())
            await connections.add(connection, server: server)
        }
        await server.waitUntilCompleted()
        await connections.remove(id)
    }

    private func register(on server: Server, client: ClientName) async {
        let host = host
        await server.withMethodHandler(ListTools.self) { _ in ListTools.Result(tools: ToolCatalog.tools) }
        await server.withMethodHandler(CallTool.self) { params in
            let name = await client.name
            if let refusal = await Self.refusal(for: name, host: host) {
                return CallTool.Result(content: [.text(refusal)], isError: true)
            }
            return await ToolRunner(host: host, client: name).run(params.name, params.arguments)
        }
        await server.withMethodHandler(ListResources.self) { _ in ListResources.Result(resources: ResourceCatalog.resources) }
        await server.withMethodHandler(ListResourceTemplates.self) { _ in
            ListResourceTemplates.Result(templates: ResourceCatalog.templates)
        }
        await server.withMethodHandler(ReadResource.self) { params in
            let name = await client.name
            if let refusal = await Self.refusal(for: name, host: host) { throw MCPError.invalidRequest(refusal) }
            return try await ResourceCatalog.read(params.uri, runner: ToolRunner(host: host, client: name))
        }
    }

    /// Why a client may not use Cue yet, or nil when it may.
    static func refusal(for client: String, host: DeckHost) async -> String? {
        switch await host.approval(for: client) {
        case .approved: nil
        case .pending: CueMCPError.notApproved(client).errorDescription
        case .denied: CueMCPError.denied(client).errorDescription
        }
    }
}

/// The connected client's name, known once it has sent `initialize`.
actor ClientName {
    private(set) var name = "an MCP client"
    func set(_ value: String) { name = value }
}
