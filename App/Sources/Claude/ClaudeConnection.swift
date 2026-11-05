import AppKit
import CueCore
import CueEditor
import CueMCP
import Observation

/// Cue's link to the user's own Claude (Claude Code or Claude Desktop) over
/// MCP. Owns the socket listener and the server, asks the user to approve
/// new clients, and hands Ask-bar requests to Claude. Cue never signs in to
/// Claude itself: the work runs in Anthropic's apps, on the user's plan.
@MainActor @Observable
final class ClaudeConnection {
    static let shared = ClaudeConnection()

    private(set) var listenerState = MCPSocketListener.State.stopped
    private(set) var clients: [MCPConnectionInfo] = []
    /// Clients waiting for Allow / Don't Allow.
    private(set) var awaitingApproval: [String] = []
    let approvals = ClientApproval()
    /// What the agent is doing right now, for the Ask bar.
    let activity = ClaudeActivity()

    /// The editor Claude works on: set by the app (front-most deck window).
    @ObservationIgnored var frontSession: () -> EditorSession? = { nil }

    @ObservationIgnored private let mailbox = RequestMailbox()
    @ObservationIgnored private var server: CueMCPServer?
    @ObservationIgnored private var listener: MCPSocketListener?
    /// Ask-bar requests in flight: mailbox id → where to report progress.
    @ObservationIgnored private var asks: [String: (session: EditorSession, id: UUID)] = [:]

    /// The helper Claude runs, inside Cue.app.
    var helperPath: String { Bundle.main.bundleURL.appending(path: "Contents/MacOS/cue-mcp").path }

    func start() {
        guard listener == nil else { return }
        let host = MCPHostController(
            mailbox: mailbox, approvals: approvals,
            frontSession: { ClaudeConnection.shared.frontSession() },
            askUser: { ClaudeConnection.shared.ask(toApprove: $0) }
        )
        let server = CueMCPServer(host: host)
        let listener = MCPSocketListener(server: server)
        self.server = server
        self.listener = listener
        Task {
            await server.connections.observe { list in Task { @MainActor in ClaudeConnection.shared.clients = list } }
            await mailbox.observe { request in Task { @MainActor in ClaudeConnection.shared.update(request) } }
        }
        do {
            try listener.start { state in Task { @MainActor in ClaudeConnection.shared.listenerState = state } }
        } catch {
            listenerState = .failed(error.localizedDescription)
        }
    }

    func stop() { listener?.stop() }

    // MARK: Approval

    func ask(toApprove client: String) {
        if !awaitingApproval.contains(client) { awaitingApproval.append(client) }
    }

    func answer(_ client: String, allow: Bool) {
        approvals.set(allow ? .approved : .denied, for: client)
        awaitingApproval.removeAll { $0 == client }
    }

    func revoke(_ client: String) { approvals.set(.pending, for: client) }

    // MARK: Ask bar

    /// Hands a request typed in `session`'s Ask bar to Claude.
    func send(_ request: AskRequest, from session: EditorSession) {
        Task {
            let posted = await mailbox.post(request.text, slide: request.slide + 1, selection: request.selection)
            asks[posted.id] = (session, request.id)
            guard let sampler = await server?.connections.samplingServer(), let server else { return }
            // The client can run a model for Cue: serve it now instead of waiting for next_request.
            guard let taken = await mailbox.next(timeout: .zero), taken.id == posted.id else { return }
            let client = clients.first(where: \.supportsSampling)?.client ?? "claude"
            do {
                let summary = try await AskSampler.serve(taken, server: sampler, host: server.host, client: client)
                try await mailbox.complete(taken.id, summary: summary)
            } catch {
                try? await mailbox.complete(taken.id, summary: "Couldn't do it: \(error.localizedDescription)")
            }
        }
    }

    private func update(_ request: RequestMailbox.Request) {
        guard let link = asks[request.id] else { return }
        switch request.status {
        case .waiting: link.session.askQueue.mark(link.id, .waiting)
        case .working: link.session.askQueue.mark(link.id, .inProgress)
        case .done: link.session.askQueue.mark(link.id, .done, summary: request.summary)
        case .cancelled: link.session.askQueue.mark(link.id, .cancelled)
        }
        if request.status == .done || request.status == .cancelled { asks[request.id] = nil }
    }

    var isListening: Bool {
        if case .listening = listenerState { true } else { false }
    }
}
