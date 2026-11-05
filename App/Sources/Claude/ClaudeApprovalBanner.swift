import CueUI
import SwiftUI

/// "Claude Code wants to edit decks in Cue": shown in deck windows the first
/// time a client connects. Until the user answers, Cue's tools tell Claude
/// it's waiting for approval.
struct ClaudeApprovalBanner: View {
    let connection: ClaudeConnection

    var body: some View {
        VStack(spacing: 8) {
            ForEach(connection.awaitingApproval, id: \.self) { client in
                Banner(
                    systemImage: "sparkles",
                    message: "“\(client)” wants to edit decks in Cue.",
                    detail: "It can read and change the open deck. Every change shows up here to accept or undo.",
                    actions: [
                        .init("Don't Allow") { connection.answer(client, allow: false) },
                        .init("Allow", kind: .primary) { connection.answer(client, allow: true) },
                    ]
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, connection.awaitingApproval.isEmpty ? 0 : 8)
    }
}
