import CueCore
import CueEditor
import CueUI
import SwiftUI

/// "Ask Cue to change this slide…". Requests go to the user's own Claude
/// (Claude Code or Claude Desktop, connected over MCP). The line under the
/// bar says what's happening: waiting, working, done, or how to connect.
struct EditorAskBar: View {
    let session: EditorSession
    let connection: ClaudeConnection
    @State private var text = ""

    var body: some View {
        VStack(spacing: 6) {
            AskBar(text: $text, suggestions: suggestions, onSubmit: send, onSuggestion: { text = $0 })
                .frame(maxWidth: 780)
            if let status {
                HStack(spacing: 6) {
                    if status.busy { ProgressView().controlSize(.mini).tint(.white) }
                    Text(status.text).lineLimit(1)
                }
                .font(.system(size: 11.5))
                .foregroundStyle(CueTheme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    private var suggestions: [String] {
        session.selection == nil ? ["Tighten the headline"] : ["Make this shorter", "Build this in"]
    }

    private var status: (text: String, busy: Bool)? {
        guard let request = session.askQueue.latest else { return nil }
        switch request.status {
        case .waiting where connection.clients.isEmpty:
            return ("Claude isn't connected. Settings › Claude shows how to connect Claude Code.", false)
        case .waiting:
            let count = session.askQueue.open.count
            return (count == 1 ? "Waiting for Claude…" : "Waiting for Claude… \(count) requests queued", true)
        case .inProgress: return ("Claude is working…", true)
        case .done: return (request.summary.map { "Claude: \($0)" } ?? "Done", false)
        case .cancelled: return nil
        }
    }

    private func send() {
        guard session.ask(text) != nil else { return }
        text = ""
    }
}
