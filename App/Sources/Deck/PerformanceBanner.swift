import CueUI
import SwiftUI

/// "This deck keeps your GPU busy…", with a prompt to hand the user's AI.
struct PerformanceBanner: View {
    let warning: DeckPerformanceWarning

    var body: some View {
        Group {
            if warning.isShown {
                Banner(
                    systemImage: "gauge.with.dots.needle.67percent",
                    message: warning.report.message,
                    detail: warning.copied
                        ? "Copied. Paste it into Claude Code or Claude Desktop; Claude works on the deck through Cue."
                        : "It will drain your battery and may stutter on a projector. Your AI can make it lighter.",
                    actions: [
                        .init(warning.copied ? "Copy Again" : "Copy Prompt for Your AI", kind: .primary) {
                            warning.copyPrompt()
                        },
                        .init("Not Now") { warning.notNow() },
                        .init("Never for This Deck") { warning.neverForThisDeck() },
                    ]
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: warning.isShown)
    }
}
