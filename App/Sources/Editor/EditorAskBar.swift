import CueEditor
import CueUI
import SwiftUI

/// "Ask Cue to change this slide…". Requests queue for a connected Claude
/// session (served over MCP in milestone 7); this shows that they're waiting.
struct EditorAskBar: View {
    let session: EditorSession
    @State private var text = ""

    var body: some View {
        VStack(spacing: 6) {
            AskBar(text: $text, suggestions: suggestions, onSubmit: send, onSuggestion: { text = $0 })
                .frame(maxWidth: 780)
            if session.waitingRequests > 0 {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(.white)
                    Text(waitingText)
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

    private var waitingText: String {
        let count = session.waitingRequests
        return count == 1 ? "Waiting for Claude…" : "Waiting for Claude… \(count) requests queued"
    }

    private func send() {
        guard session.ask(text) != nil else { return }
        text = ""
    }
}
