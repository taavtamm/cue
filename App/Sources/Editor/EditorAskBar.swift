import AppKit
import CueCore
import CueEditor
import CueUI
import SwiftUI

/// "Ask Cue to change this slide…", and below it what the agent is doing:
/// not connected, listening, reading, editing (the bar's glow speeds up and
/// shimmers), what it just changed with Undo, or requests waiting for it.
/// Requests go to the user's own Claude (Claude Code or Claude Desktop over MCP).
struct EditorAskBar: View {
    let session: EditorSession
    let connection: ClaudeConnection
    @State private var text = ""
    /// The kept change whose "Changed …" line has timed out.
    @State private var changeShown: String?

    static let changeNoticeSeconds = 8

    var body: some View {
        let status = self.status
        VStack(spacing: 6) {
            AskBar(text: $text, placeholder: placeholder, suggestions: suggestions, onSubmit: send,
                   onSuggestion: { text = $0 }, activity: status.activity)
                .frame(maxWidth: 780)
            AskStatusLine(status.text, tone: status.tone, action: status.action)
                .animation(.easeInOut(duration: 0.2), value: status.text)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .task(id: session.claudeChanges.latestUndoable?.id) { await expireChangeNotice() }
    }

    private var placeholder: String {
        connection.clients.isEmpty ? "Connect an agent to ask Cue to change this slide…" : "Ask Cue to change this slide…"
    }

    private var suggestions: [String] {
        session.selection == nil ? ["Tighten the headline"] : ["Make this shorter", "Build this in"]
    }

    private struct Status {
        var text: String
        var tone: AskStatusLine.Tone
        var activity: AskBarActivity
        var action: (title: String, run: () -> Void)?
    }

    private var status: Status {
        let activity = connection.activity
        if connection.clients.isEmpty {
            let queued = session.askQueue.open.count
            let text = queued > 0 ? "Agent not connected · \(queued) waiting" : "Agent not connected"
            return Status(text: text, tone: .offline, activity: .offline, action: ("Connect…", Self.openClaudeSettings))
        }
        if let entry = activity.shown {
            let editing = entry.kind == .editing
            return Status(text: ClaudeActivity.describe(entry), tone: editing ? .editing : .working,
                          activity: editing ? .editing : .working)
        }
        if let request = session.askQueue.latest, request.status == .inProgress {
            return Status(text: "Working on “\(request.text)”…", tone: .working, activity: .working)
        }
        if let change = recentChange {
            return Status(text: "Changed: \(change.summary)", tone: .done, activity: .idle,
                          action: ("Undo", { Task { try? await session.revertClaudeChange(change.id) } }))
        }
        let waiting = session.askQueue.open.count
        let listening = !activity.listeningClients.isEmpty
        if waiting > 0, !listening {
            return Status(text: waiting == 1 ? "1 request waiting · your agent isn't listening for the Ask bar"
                                              : "\(waiting) requests waiting · your agent isn't listening for the Ask bar",
                          tone: .working, activity: .working)
        }
        if waiting > 0 { return Status(text: "Sending to your agent…", tone: .working, activity: .working) }
        if listening { return Status(text: "\(agentName) is listening", tone: .listening, activity: .listening) }
        return Status(text: "\(agentName) connected", tone: .idle, activity: .idle)
    }

    private var agentName: String {
        let name = connection.clients.first?.client ?? "Agent"
        return name == "claude-code" ? "Claude Code" : name
    }

    /// A kept change from the last few seconds, with Undo.
    private var recentChange: ChangeSet? {
        guard let change = session.claudeChanges.latestUndoable, change.status == .accepted,
              change.id != changeShown,
              Date().timeIntervalSince(change.createdAt) < Double(Self.changeNoticeSeconds) else { return nil }
        return change
    }

    private func expireChangeNotice() async {
        guard let change = session.claudeChanges.latestUndoable else { return }
        let left = Double(Self.changeNoticeSeconds) - Date().timeIntervalSince(change.createdAt)
        if left > 0 { try? await Task.sleep(for: .seconds(left)) }
        changeShown = change.id
    }

    private func send() {
        guard session.ask(text) != nil else { return }
        text = ""
    }

    static func openClaudeSettings() {
        NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: nil)
    }
}
